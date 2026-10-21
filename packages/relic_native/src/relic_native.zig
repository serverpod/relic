//! relic_native: zio + std.http.Server driven from the Dart isolate's own
//! thread. One reactor per isolate, ticked by Dart, and one acceptor
//! thread per server group, handing connections to the least-loaded
//! reactor.
//!
//! Flow per request, all of it on the isolate thread except the accept:
//!   acceptor thread: accept -> push the socket to a reactor -> poke its
//!                    waiter
//!   Dart:            relic_reactor_tick() runs the reactor's tasks and
//!                    polls its loop once, and returns the exchanges that
//!                    became ready for a handler
//!   task:            receiveHead -> parseHead -> read inline body ->
//!                    push the Exchange on the ready list -> park on
//!                    exchange.done
//!   Dart:            handles it and sets exchange.done, and the next tick
//!                    writes the response. relic_respond_inline() leaves
//!                    the encoded head and body in the connection's write
//!                    buffer when they fit. relic_respond() hands them
//!                    back otherwise, malloc'd, with ownership
//!                    transferred
//!   task:            writes, frees what relic_respond() handed back,
//!                    loops for keep-alive.
//! Sockets are only ever touched by tasks. Dart only touches Exchanges, and
//! only between ticks, so nothing here needs a lock except what the
//! acceptor thread shares.
//!
//! A body over the inline limit, or chunked, streams to Dart through the
//! exchange's inbound chunk queue while the handler runs, with credit
//! from Dart bounding how far the task reads ahead. A response without a
//! buffer streams back through the outbound chunk queue, chunked on the
//! wire when its length is unknown.
//!
//! A connection Dart upgrades to a WebSocket stays with its task, which
//! frames, unmasks and checks on this thread. Dart sends and receives
//! whole messages through the same two queues.
//!
//! While Dart has nothing to do it parks a waiter thread on the loop's
//! host handle, which wakes it with one port message when the loop has
//! events or a timer is due. Under load the isolate never gets there.

const std = @import("std");
const builtin = @import("builtin");
const zio = @import("zio");
const dart = @import("dart_dl");
const header_names = @import("header_names.zig");

const max_head = 16 * 1024;
const max_headers = 128;
/// How long an accept waits before the loop looks at the stop flag again.
/// A stop pokes the acceptor awake (pokeAcceptor), so this only matters
/// when the poke's SYN was dropped.
const accept_timeout_ms = 1000;
/// How long the acceptor waits after an accept failed for want of a
/// descriptor or a buffer, before it tries again. nginx waits 500 ms.
const accept_backoff_ms = 100;
/// Accepts that failed for want of a descriptor or a buffer and were
/// retried.
var accept_shortages = std.atomic.Value(u32).init(0);
/// Bytes per inbound chunk of a streamed request body.
const in_chunk_size = 64 * 1024;
/// Chunks the task reads ahead of Dart on a streamed request body.
const in_credit = 4;
/// The task drains an unread body up to this many bytes to keep the
/// connection, and closes it beyond that.
const max_discard = 4 << 20;
/// The largest payload of a WebSocket control frame (RFC 6455 5.5).
const ws_control_max = 125;
/// How long a close frame this side sent waits for the peer's answer
/// before the connection ends anyway.
const ws_close_wait_ms = 2000;
/// How long a WebSocket frame about to die waits for Dart to take the
/// messages still queued for it, the peer's close among them.
const ws_drain_wait_ms = 1000;

/// What the waiter's pipe, pokeAcceptor and the tests need from libc.
/// Zig keeps sockets behind std.Io, and the reactor's thread cannot use
/// that.
const libc = struct {
    extern "c" fn pipe(fds: *[2]c_int) c_int;
    extern "c" fn socket(domain: c_int, sock_type: c_int, protocol: c_int) c_int;
    extern "c" fn connect(fd: c_int, addr: *const anyopaque, len: u32) c_int;
    extern "c" fn write(fd: c_int, buf: [*]const u8, len: usize) isize;
    extern "c" fn read(fd: c_int, buf: [*]u8, len: usize) isize;
    extern "c" fn close(fd: c_int) c_int;
    extern "c" fn fcntl(fd: c_int, cmd: c_int, ...) c_int;
};

// FFI-visible layout, mirrored by Dart structs in lib/src/bindings.dart.
// test/bindings_layout_test.dart holds the Dart structs to their sizes.

pub const Options = extern struct {
    /// Reactors a server accepts. More than this many fail to attach.
    reactor_capacity: u32,
    backlog: u32,
    /// Connections accepted at once. 0 means no limit. Above it the accept
    /// loop waits, and the kernel backlog holds the rest.
    max_connections: u32,
    max_inline_body: u64,
    /// Waiting for the first byte of a request on a connection. 0 = none.
    idle_timeout_ms: u32,
    /// From the first byte of a request to the end of its head. 0 = none.
    header_timeout_ms: u32,
    /// Inactivity while reading a request body. 0 = none.
    body_timeout_ms: u32,
    /// Inactivity while writing a response. 0 = none.
    write_timeout_ms: u32,
};

pub const HeaderSlot = extern struct {
    name_off: u32,
    /// The id of the name in header_names.zig, or -1 for a name outside
    /// the table. The name runs from `name_off` to the colon.
    name_id: i32,
    value_off: u32,
    value_len: u32,
};

/// What Dart sees. Offsets are into `head`.
pub const ExchangeView = extern struct {
    method: u8, // see dartMethod
    version: u8, // 0 = HTTP/1.0, 1 = HTTP/1.1
    keep_alive: u8,
    remote_family: u8, // 4 or 6
    remote_port: u16,
    local_port: u16,
    remote_addr: [16]u8, // 4 or 16 bytes, network order
    head: [*]const u8,
    head_len: u32,
    target_off: u32,
    target_len: u32,
    header_count: u32,
    headers: [*]const HeaderSlot,
    body: ?[*]const u8,
    /// Inline body length, or the declared length of a streamed body, or
    /// 0 for a chunked one.
    body_len: u64,
    /// The peer watcher or pumpRequestBody sets this when the connection
    /// reached EOF or a body read failed while the exchange was parked.
    /// Dart completes `cancelled` on it.
    peer_gone: u8 = 0,
    /// The body was not read inline. Dart pulls it with relic_read_chunk.
    body_streamed: u8 = 0,
    /// A write of the streamed response failed. Dart stops feeding it.
    write_failed: u8 = 0,
    /// Outbound chunks written so far, for Dart's flow control.
    chunks_written: u32 = 0,
    /// The connection's write buffer while it is empty. Dart encodes a
    /// response that fits straight into it and answers with
    /// relic_respond_inline. Null when the buffer holds bytes.
    scratch: ?[*]u8 = null,
    scratch_cap: u32 = 0,
    /// Pong frames received, for Dart's ping timer.
    ws_pongs: u32 = 0,
};

pub const Stats = extern struct {
    /// Connections with a request in flight.
    active: u32,
    /// Keep-alive connections waiting for their next request.
    idle: u32,
    /// The lowest attached reactor slot. That isolate reports the shared
    /// counts and the others report zero, so a sum over isolates is one
    /// snapshot.
    first_attached: u32,
};

/// Returned in `Stats.first_attached` when no reactor is attached.
pub const no_slot: u32 = std.math.maxInt(u32);

const Node = struct {
    next: std.atomic.Value(?*Node) = .init(null),
};

/// Intrusive MPSC queue (Vyukov), for what crosses from the acceptor
/// thread to a reactor. Producers on any thread, one consumer.
const Mpsc = struct {
    head: std.atomic.Value(*Node), // producers swap here
    tail: *Node, // consumer only
    stub: Node = .{},

    fn init(self: *Mpsc) void {
        self.* = .{ .head = .init(&self.stub), .tail = &self.stub };
    }

    fn push(self: *Mpsc, n: *Node) void {
        n.next.store(null, .monotonic);
        const prev = self.head.swap(n, .acq_rel);
        prev.next.store(n, .release);
    }

    fn pop(self: *Mpsc) ?*Node {
        var tail = self.tail;
        var next = tail.next.load(.acquire);
        if (tail == &self.stub) {
            const n = next orelse return null;
            self.tail = n;
            tail = n;
            next = n.next.load(.acquire);
        }
        if (next) |n| {
            self.tail = n;
            return tail;
        }
        // A producer is between its swap and its link. Report empty.
        if (tail != self.head.load(.acquire)) return null;
        self.push(&self.stub);
        if (tail.next.load(.acquire)) |n| {
            self.tail = n;
            return tail;
        }
        return null;
    }
};

/// A plain FIFO for what stays on the reactor thread.
const Fifo = struct {
    head: ?*Node = null,
    tail: ?*Node = null,

    fn push(self: *Fifo, n: *Node) void {
        n.next.store(null, .monotonic);
        if (self.tail) |t| t.next.store(n, .monotonic) else self.head = n;
        self.tail = n;
    }

    fn pop(self: *Fifo) ?*Node {
        const n = self.head orelse return null;
        self.head = n.next.load(.monotonic);
        if (self.head == null) self.tail = null;
        return n;
    }

    fn isEmpty(self: *const Fifo) bool {
        return self.head == null;
    }
};

/// One piece of a streamed body, in either direction. The data buffer is
/// malloc'd. Dart allocates an outbound one and hands it over. The task
/// allocates an inbound one, and Dart frees it with relic_free.
const Chunk = struct {
    node: Node = .{},
    ptr: ?[*]u8,
    len: usize,
    /// The last chunk. `ok` false means the producer failed, so the
    /// consumer drops the connection instead of finishing the message.
    last: bool = false,
    ok: bool = true,
    /// On a WebSocket: a `WsKind` inbound, a `WsOpcode` outbound. 0 for
    /// a body chunk.
    kind: u8 = 0,
};

/// An accepted socket on its way from the acceptor thread to a reactor.
const Incoming = struct {
    node: Node = .{},
    stream: zio.net.Stream,
};

/// Lives on the connection task's stack for one request.
const Exchange = struct {
    view: ExchangeView,
    node: Node = .{},
    reactor: *Reactor,
    // The relic_respond functions, relic_abort, relic_hijack and
    // relic_ws_upgrade set the answer before `done`.
    /// Status line, headers and CRLF, encoded by Dart. Owned here.
    resp_head: ?[*]u8 = null,
    resp_head_len: u32 = 0,
    /// The body, owned here, or null for a streamed or inline one.
    resp_body: ?[*]u8 = null,
    resp_body_len: u64 = 0,
    /// The bytes of a response Dart wrote into the view's `scratch`, or 0.
    resp_inline_len: u32 = 0,
    /// The body follows through relic_write_chunk.
    resp_streamed: bool = false,
    /// Chunked transfer coding on the wire, for a length Dart did not know.
    resp_chunked: bool = false,
    close_after: bool = false,
    aborted: bool = false,
    /// Dart took the connection as a raw byte channel.
    hijacked: bool = false,
    /// Dart made the connection a WebSocket.
    upgraded: bool = false,
    /// A WebSocket message over this many bytes closes the connection
    /// with 1009.
    ws_max_message: u32 = 0,
    /// Set by Dart when it answered, aborted or hijacked.
    done: zio.Event = .init,
    /// Set by Dart when a handler asks for `cancelled`. The task then
    /// watches the socket for EOF while it waits.
    watch: zio.Event = .init,
    /// Outbound chunks from Dart, which sets `out_ready` after every push.
    out: Fifo = .{},
    out_ready: zio.Event = .init,
    /// Inbound chunks for Dart, which sets `credit` after it takes one.
    in: Fifo = .{},
    in_pending: u32 = 0,
    credit: zio.Event = .init,
    /// The hijacked or WebSocket connection is over. Dart closed its sink
    /// or aborted, or the close handshake finished.
    closed: zio.Event = .init,
    /// Dart closed the sink of a hijacked connection. From then on the
    /// only event Dart gets is the last one, once the connection is gone.
    sink_closed: bool = false,
    /// The peer has nothing more to say on a WebSocket. Its close frame
    /// arrived, the connection ended, or it broke the protocol.
    peer_close: zio.Event = .init,
    /// A close frame is queued or written on a WebSocket. After it the
    /// task hands Dart no message and answers no ping.
    ws_close_sent: bool = false,

    fn init(self: *Exchange, reactor: *Reactor, view: ExchangeView) void {
        self.* = .{ .view = view, .reactor = reactor };
    }
};

/// Tells Dart something happened to a parked exchange. Dart drains the
/// list after every tick with relic_reactor_events. The address is all
/// Dart gets.
fn postExchangeEvent(ex: *Exchange) void {
    ex.reactor.events.append(ex.reactor.gpa, @intFromPtr(&ex.view)) catch {};
}

/// The last event of a hijacked connection, posted by a frame about to
/// die. The low bit of the address tells Dart not to look at the view.
fn postLastEvent(ex: *Exchange) void {
    ex.reactor.events.append(ex.reactor.gpa, @intFromPtr(&ex.view) | 1) catch {};
}

/// One per isolate, on that isolate's thread.
pub const Reactor = struct {
    gpa: std.mem.Allocator,
    server: *Server,
    slot: u32,
    port: dart.Dart_Port_DL,
    rt: *zio.Runtime,
    /// The connection tasks. Cancelled on destroy.
    group: zio.Group = .init,
    /// Sockets from the acceptor thread, spawned at the next tick.
    incoming: Mpsc = undefined,
    /// Exchanges a handler has not seen yet.
    ready: Fifo = .{},
    /// Addresses of exchanges with something to tell Dart, the last
    /// event of a hijacked connection tagged in the low bit.
    events: std.ArrayListUnmanaged(usize) = .empty,
    events_taken: usize = 0,
    /// The last tick left ready tasks behind, so the next one must come
    /// without a wait.
    pending: bool = false,
    waiter: std.Thread = undefined,
    waiter_arm: zio.os.ResetEvent = .init(),
    waiter_stop: std.atomic.Value(bool) = .init(false),
    poke: Poke = .{},
    /// The waiter is in its poll, with `waiter_until` as its deadline in
    /// milliseconds of loop time, or max when it has none.
    waiter_armed: std.atomic.Value(bool) = .init(false),
    waiter_until: std.atomic.Value(i64) = .init(std.math.maxInt(i64)),
    /// Shared with the acceptor thread, which balances on it.
    connections: std.atomic.Value(u32) = .init(0),
    /// Shared with the acceptor thread, which passes over a reactor that
    /// stopped.
    accepting: std.atomic.Value(bool) = .init(true),
    active: std.atomic.Value(u32) = .init(0),
    idle: std.atomic.Value(u32) = .init(0),
    stop: bool = false,
    /// The open connections, for the sweeper to walk.
    conns: std.DoublyLinkedList = .{},
    sweeping: bool = false,

    fn pokeWaiter(self: *Reactor) void {
        self.poke.poke();
    }

    /// Lists the connection and starts the sweeper when it is not
    /// running. A server with no timeout the sweeper enforces has none.
    fn addConn(self: *Reactor, conn: *Conn) void {
        self.conns.append(&conn.node);
        if (self.sweeping or sweepInterval(self.server.options) == 0) return;
        self.sweeping = true;
        self.group.spawn(sweep, .{self}) catch {
            self.sweeping = false;
        };
    }

    /// Spawns a connection task for every socket the acceptor handed over.
    /// Assumes a tick has bound the executor to this thread.
    fn drainIncoming(self: *Reactor) void {
        while (self.incoming.pop()) |node| {
            const inc: *Incoming = @fieldParentPtr("node", node);
            const stream = inc.stream;
            self.gpa.destroy(inc);
            self.group.spawn(handleConn, .{ self, stream }) catch {
                _ = self.connections.fetchSub(1, .monotonic);
                stream.close();
                continue;
            };
            self.pending = true;
        }
    }
};

/// Ends the waiter's wait before its deadline, to stop it or to re-arm
/// it with an earlier deadline. A pipe, polled alongside the loop's
/// handle where the loop has one. On Windows the loop has none, so a
/// futex word stands in and the wait is bounded, which keeps an idle
/// loop looked at.
const Poke = if (builtin.os.tag == .windows) struct {
    word: std.atomic.Value(u32) = .init(0),

    fn init(self: *Poke) bool {
        _ = self;
        return true;
    }

    fn deinit(self: *Poke) void {
        _ = self;
    }

    fn poke(self: *Poke) void {
        _ = self.word.fetchAdd(1, .release);
        zio.os.Futex.wake(&self.word, .one);
    }

    /// Waits for a poke or `timeout_ms`, 10 ms when there is no deadline.
    fn wait(self: *Poke, host: anytype, timeout_ms: i32) void {
        _ = host;
        const seen = self.word.load(.acquire);
        const ms: u32 = if (timeout_ms < 0) 10 else @intCast(timeout_ms);
        zio.os.Futex.timedWait(&self.word, seen, .fromMilliseconds(ms)) catch {};
    }
} else struct {
    pipe: [2]c_int = .{ -1, -1 },

    fn init(self: *Poke) bool {
        return libc.pipe(&self.pipe) == 0;
    }

    fn deinit(self: *Poke) void {
        _ = libc.close(self.pipe[0]);
        _ = libc.close(self.pipe[1]);
    }

    fn poke(self: *Poke) void {
        _ = libc.write(self.pipe[1], "x", 1);
    }

    /// Polls the pipe and `host` until one is readable or `timeout_ms`
    /// passes. No handle to wait on means a short wait, so the loop is
    /// still looked at. poll ignores a negative fd.
    fn wait(self: *Poke, host: anytype, timeout_ms: i32) void {
        var fds = [_]std.posix.pollfd{
            .{ .fd = self.pipe[0], .events = std.posix.POLL.IN, .revents = 0 },
            .{ .fd = host orelse -1, .events = std.posix.POLL.IN, .revents = 0 },
        };
        const bounded: i32 = if (fds[1].fd < 0 and timeout_ms < 0) 10 else timeout_ms;
        _ = std.posix.poll(&fds, bounded) catch {};
        if (fds[0].revents != 0) {
            var drain: [16]u8 = undefined;
            _ = libc.read(self.pipe[0], &drain, drain.len);
        }
    }
};

/// Blocks on the loop's host handle until it has events or the next
/// timer is due, then posts one message to the isolate. Armed by Dart
/// through relic_reactor_wait each time it has nothing to do.
fn waiterThread(r: *Reactor) void {
    while (true) {
        r.waiter_arm.wait();
        r.waiter_arm.reset();
        if (r.waiter_stop.load(.acquire)) return;
        const loop = &r.rt.main_executor.loop;
        const until = r.waiter_until.load(.acquire);
        const timeout: i32 = if (until == std.math.maxInt(i64))
            -1
        else
            @intCast(@max(0, @min(until - nowMs(), std.math.maxInt(i32))));
        r.poke.wait(loop.hostHandle(), timeout);
        r.waiter_armed.store(false, .release);
        if (r.waiter_stop.load(.acquire)) return;
        if (dart.Dart_PostInteger_DL) |post| _ = post(r.port, 0);
    }
}

/// The acceptor, one per group, shared by the isolates of the group. The
/// last reactor to detach stops it.
pub const Server = struct {
    gpa: std.mem.Allocator,
    reactors: []?*Reactor,
    address: zio.net.IpAddress,
    options: Options,
    /// Registry key, owned. Null for a server outside the registry.
    group: ?[]u8,
    thread: std.Thread = undefined,
    stop: std.atomic.Value(bool) = .init(false),
    /// Set once the listener is bound or binding failed.
    bound: zio.os.ResetEvent = .init(),
    bound_port: std.atomic.Value(u16) = .init(0),
    bind_failed: std.atomic.Value(bool) = .init(false),
    /// Held by attach, detach and dispatch, so a reactor never disappears
    /// under the acceptor. Uncontended on the request path.
    attach_lock: zio.os.Mutex = .{},
    attached_count: u32 = 0,
    /// Rotates the start of the least-loaded scan, so ties spread out.
    next_start: u32 = 0,

    fn connectionsTotal(self: *Server) u32 {
        self.attach_lock.lock();
        defer self.attach_lock.unlock();
        var total: u32 = 0;
        for (self.reactors) |maybe| {
            if (maybe) |r| total += r.connections.load(.monotonic);
        }
        return total;
    }

    /// Hands the socket to the reactor with the fewest connections and
    /// pokes its waiter. Returns false when no reactor is attached.
    fn dispatch(self: *Server, stream: zio.net.Stream) bool {
        self.attach_lock.lock();
        defer self.attach_lock.unlock();

        const n: u32 = @intCast(self.reactors.len);
        self.next_start +%= 1;
        const start = self.next_start % n;
        var best: ?*Reactor = null;
        var best_load: u32 = std.math.maxInt(u32);
        for (0..n) |k| {
            const r = self.reactors[(start + k) % n] orelse continue;
            if (!r.accepting.load(.acquire)) continue;
            const load = r.connections.load(.monotonic);
            if (best == null or load < best_load) {
                best = r;
                best_load = load;
            }
        }
        const r = best orelse return false;
        const inc = self.gpa.create(Incoming) catch return false;
        inc.* = .{ .stream = stream };
        _ = r.connections.fetchAdd(1, .monotonic);
        r.incoming.push(&inc.node);
        // The isolate learns of it through the waiter's pipe, not a wake
        // of the loop. Loop.wake coalesces on a flag that only a real poll
        // clears, and a loop with nothing in flight returns from poll
        // before that, so a wake posted to an idle loop can be the last
        // one that reaches the kernel.
        r.pokeWaiter();
        return true;
    }

    fn run(self: *Server) void {
        self.runInner() catch |err| {
            std.log.err("relic_native: {t}", .{err});
            self.bind_failed.store(true, .release);
            self.bound.set();
        };
    }

    fn runInner(self: *Server) !void {
        const rt = try zio.Runtime.init(self.gpa, .{ .executors = .exact(1) });
        defer rt.deinit();

        const listener = try self.address.listen(.{
            .reuse_address = true,
            .kernel_backlog = @intCast(@min(self.options.backlog, std.math.maxInt(u31))),
        });
        defer listener.close();
        self.bound_port.store(listener.socket.address.ip.getPort(), .release);
        self.bound.set();

        const max_connections = self.options.max_connections;
        while (!self.stop.load(.acquire)) {
            if (max_connections != 0 and self.connectionsTotal() >= max_connections) {
                // Full. Leave new connections in the kernel backlog until one
                // of ours ends.
                try zio.sleep(.fromMilliseconds(1));
                continue;
            }
            const stream = listener.accept(.{
                .timeout = .fromMilliseconds(accept_timeout_ms),
            }) catch |err| switch (err) {
                error.Timeout => continue,
                error.ProcessFdQuotaExceeded, error.SystemFdQuotaExceeded, error.SystemResources => {
                    // A connection ending frees what accept needs, and
                    // the listener is fine, so the server stays up. Linux
                    // keeps the connection the failed accept was for,
                    // XNU drops it.
                    std.log.warn("relic_native: accept failed with {t}", .{err});
                    _ = accept_shortages.fetchAdd(1, .monotonic);
                    try zio.sleep(.fromMilliseconds(accept_backoff_ms));
                    continue;
                },
                else => return err,
            };
            if (self.stop.load(.acquire)) {
                stream.close();
                break;
            }
            // What uSockets and Deno set on every accepted socket. A
            // response is one send, so Nagle has nothing to coalesce and
            // only costs the check.
            stream.socket.setNoDelay(true) catch {};
            if (!self.dispatch(stream)) stream.close();
        }
    }
};

fn handleConn(r: *Reactor, stream: zio.net.Stream) void {
    defer _ = r.connections.fetchSub(1, .monotonic);
    _ = r.idle.fetchAdd(1, .monotonic);
    defer _ = r.idle.fetchSub(1, .monotonic);
    handleConnInner(r, stream) catch |err| switch (err) {
        error.HttpConnectionClosing, error.ReadFailed, error.WriteFailed, error.Canceled => {},
        else => std.log.debug("relic_native: connection ended with {t}", .{err}),
    };
}

/// A task of this reactor, as the executor names the one that is running.
const Task = @typeInfo(@FieldType(@FieldType(zio.Runtime, "main_executor"), "current_task")).optional.child;

/// What the sweeper needs of a connection: when its task must have made
/// progress by, and the task to cancel when it has not.
///
/// The waits on the hot path carry no timeout of their own: the wait for
/// the next request, the read of its head, and the write of a small
/// response held in memory. A zio timeout puts a timer and a race group
/// around every receive and send. One deadline per connection and one
/// sweep per interval costs a store per phase instead. Body reads,
/// streamed responses and the lingering close keep their zio timeouts.
const Conn = struct {
    node: std.DoublyLinkedList.Node = .{},
    task: Task,
    /// Clock time in milliseconds by which the phase must end, 0 for no
    /// limit.
    deadline: i64 = 0,
    /// The sweeper found the deadline passed and cancelled the task.
    timed_out: bool = false,
    /// Waiting for the first byte of a request.
    idle: bool = false,

    /// Starts a phase that must end within `ms`, or without a limit for 0.
    fn arm(self: *Conn, ms: u32) void {
        self.settle();
        self.deadline = if (ms == 0) 0 else nowMs() + ms;
    }

    /// Ends the phase.
    fn disarm(self: *Conn) void {
        self.deadline = 0;
        self.settle();
    }

    /// Whether the sweeper ended the wait that just failed.
    fn expired(self: *Conn) bool {
        const was = self.timed_out;
        self.timed_out = false;
        return was;
    }

    /// Takes back a cancel the sweeper sent for a wait that completed
    /// anyway. zio hands such a cancel to the task's next wait, which
    /// must not be the park. Dart holds the frame until it answers.
    fn settle(self: *Conn) void {
        if (!self.timed_out) return;
        self.timed_out = false;
        self.task.checkCancel() catch {};
    }
};

/// The largest inline body buffer a connection keeps for its next
/// request. A larger one is freed when its request is done.
const body_store_keep = 64 * 1024;

/// The largest response body written under the sweeper's deadline. The
/// write timeout is an inactivity limit. One deadline for the whole
/// response stands in for it only while a live peer takes the response
/// in one go. A larger one keeps the timeout on each send.
const swept_write_max = 64 * 1024;

/// How often the sweeper looks, in milliseconds. A quarter of the
/// shortest timeout it enforces, within 10 ms and a second, or 0 when it
/// enforces none.
fn sweepInterval(options: Options) u32 {
    var shortest: u32 = std.math.maxInt(u32);
    for ([_]u32{ options.idle_timeout_ms, options.header_timeout_ms, options.write_timeout_ms }) |ms| {
        if (ms != 0) shortest = @min(shortest, ms);
    }
    if (shortest == std.math.maxInt(u32)) return 0;
    return std.math.clamp(shortest / 4, 10, 1000);
}

/// Cancels the task of every connection past its deadline, once per
/// interval for as long as the reactor has connections. A timeout fires
/// up to one interval late.
fn sweep(r: *Reactor) void {
    defer r.sweeping = false;
    const interval = sweepInterval(r.server.options);
    while (r.conns.first != null) {
        zio.sleep(.fromMilliseconds(interval)) catch return;
        const now = nowMs();
        var next = r.conns.first;
        while (next) |node| : (next = node.next) {
            const conn: *Conn = @fieldParentPtr("node", node);
            if (conn.deadline == 0 or conn.deadline > now) continue;
            conn.deadline = 0;
            conn.timed_out = true;
            conn.task.cancel();
        }
    }
}

/// A per-operation timeout of `ms`, or none for 0.
fn inactivity(ms: u32) zio.Timeout {
    return if (ms == 0) .none else .fromMilliseconds(ms);
}

/// A deadline `ms` from now, or none for 0.
fn deadline(ms: u32) zio.Timeout {
    return if (ms == 0) .none else .{ .deadline = zio.now().addDuration(.fromMilliseconds(ms)) };
}

/// A sleep for the tests.
fn sleepMs(ms: u32) void {
    zio.os.time.sleep(.fromMilliseconds(ms));
}

/// One connection's byte streams. HTTP is read from `reader` and written
/// to `writer`. The socket's own reader and writer under them hold the
/// timeouts and record why a read or write failed.
///
/// `reader` and `writer` point into the link, so it must not move after
/// `init`.
const Link = struct {
    stream: zio.net.Stream,
    socket_reader: zio.net.Stream.Reader,
    socket_writer: zio.net.Stream.Writer,
    reader: *std.Io.Reader,
    writer: *std.Io.Writer,

    fn init(self: *Link, stream: zio.net.Stream, read_buffer: []u8, write_buffer: []u8) void {
        self.* = .{
            .stream = stream,
            .socket_reader = stream.reader(read_buffer),
            .socket_writer = stream.writer(write_buffer),
            .reader = undefined,
            .writer = undefined,
        };
        self.reader = &self.socket_reader.interface;
        self.writer = &self.socket_writer.interface;
    }

    /// Why the last read failed, or null when it ended at EOF.
    fn readError(self: *const Link) ?anyerror {
        return self.socket_reader.err;
    }

    fn timedOut(self: *const Link) bool {
        return if (self.socket_reader.err) |e| e == error.Timeout else false;
    }

    fn readCanceled(self: *const Link) bool {
        return if (self.socket_reader.err) |e| e == error.Canceled else false;
    }

    fn setReadTimeout(self: *Link, timeout: zio.Timeout) void {
        self.socket_reader.setTimeout(timeout);
    }

    fn setWriteTimeout(self: *Link, timeout: zio.Timeout) void {
        self.socket_writer.setTimeout(timeout);
    }
};

/// How long a lingering close reads and drops what the peer still sends.
const lingering_close_ms = 1000;

/// Answers with a status, then closes the way nginx's lingering close
/// does. The send side goes first. Then it reads and drops the peer's
/// remaining bytes until the peer sees the FIN and hangs up, or the
/// deadline passes. A plain close with unread input resets the
/// connection, and a peer that was still sending, which is what these
/// statuses answer, can then lose the status from its receive buffer.
fn writeStatusAndClose(link: *Link, status: []const u8) !void {
    const w = link.writer;
    try w.writeAll("HTTP/1.1 ");
    try w.writeAll(status);
    try w.writeAll("\r\nconnection: close\r\ncontent-length: 0\r\n\r\n");
    try w.flush();
    link.stream.shutdown(.send) catch return;
    link.setReadTimeout(deadline(lingering_close_ms));
    _ = link.socket_reader.interface.discard(.unlimited) catch {};
}

fn handleConnInner(r: *Reactor, stream: zio.net.Stream) !void {
    defer stream.close();

    var rbuf: [max_head]u8 = undefined;
    var wbuf: [16 * 1024]u8 = undefined;
    var link: Link = undefined;
    link.init(stream, &rbuf, &wbuf);
    var http = std.http.Server.init(link.reader, link.writer);
    const w = link.writer;

    // Per-connection scratch, reused across keep-alive requests.
    var head_copy: [max_head]u8 = undefined;
    var slots: [max_headers]HeaderSlot = undefined;
    // The body reader's own buffer, which the chunked decoder parses in.
    var tbuf: [16 * 1024]u8 = undefined;

    const peer = stream.socket.address.ip;
    const local_port = r.server.bound_port.load(.acquire);
    const options = r.server.options;
    link.setWriteTimeout(inactivity(options.write_timeout_ms));

    // Holds an inline request body, and is kept across requests while it
    // stays small.
    var body_store: std.ArrayListUnmanaged(u8) = .empty;
    defer body_store.deinit(r.gpa);

    var conn: Conn = .{ .task = r.rt.main_executor.current_task.? };
    r.addConn(&conn);
    defer r.conns.remove(&conn.node);

    while (true) {
        if (r.stop) return;
        // The first byte of a request may take the idle timeout to arrive
        // on a keep-alive connection. Once it has, the rest of the head
        // has the header deadline, which is what bounds a slowloris. The
        // sweeper holds the connection to both.
        link.setReadTimeout(.none);
        conn.arm(options.idle_timeout_ms);
        conn.idle = true;
        link.reader.fill(1) catch |err| switch (err) {
            error.EndOfStream => return,
            error.ReadFailed => return link.readError() orelse err,
        };
        conn.idle = false;
        conn.arm(options.header_timeout_ms);
        const head = http.reader.receiveHead() catch |err| switch (err) {
            error.HttpHeadersOversize => return writeStatusAndClose(&link, "431 Request Header Fields Too Large"),
            error.ReadFailed => {
                if (conn.expired()) return writeStatusAndClose(&link, "408 Request Timeout");
                return err;
            },
            else => return err,
        };
        conn.disarm();
        _ = r.idle.fetchSub(1, .monotonic);
        _ = r.active.fetchAdd(1, .monotonic);
        defer {
            _ = r.active.fetchSub(1, .monotonic);
            _ = r.idle.fetchAdd(1, .monotonic);
        }

        const index = parseHead(head, &head_copy, &slots) catch |err| switch (err) {
            error.TooManyHeaders => return writeStatusAndClose(&link, "431 Request Header Fields Too Large"),
            error.MalformedHead => return writeStatusAndClose(&link, "400 Bad Request"),
        };
        var req: std.http.Server.Request = .{ .server = &http, .head_buffer = head, .head = index.head };
        const target_off = off(head, req.head.target);
        const target_len: u32 = @intCast(req.head.target.len);
        const method = req.head.method;
        const version: u8 = if (req.head.version == .@"HTTP/1.0") 0 else 1;
        const keep_alive = req.head.keep_alive;

        // A small body with a known length is read now and handed over
        // inline. Anything else streams to Dart while the handler runs.
        const chunked = req.head.transfer_encoding == .chunked;
        const content_length = req.head.content_length;
        const stream_body = chunked or (content_length != null and content_length.? > options.max_inline_body);
        var body: ?[]u8 = null;
        defer if (body_store.capacity > body_store_keep) body_store.clearAndFree(r.gpa);
        var body_reader: ?*std.Io.Reader = null;
        if (stream_body or content_length != null) {
            const br = openBody(&req, &tbuf) catch return writeStatusAndClose(&link, "417 Expectation Failed");
            link.setReadTimeout(inactivity(options.body_timeout_ms));
            if (stream_body) {
                body_reader = br;
            } else {
                body_store.clearRetainingCapacity();
                const into = try body_store.addManyAsSlice(r.gpa, @intCast(content_length.?));
                br.readSliceAll(into) catch |err| {
                    if (link.timedOut()) return writeStatusAndClose(&link, "408 Request Timeout");
                    return err;
                };
                body = into;
            }
        }
        // The next receiveHead needs the parser back in .ready. A request with
        // a body got there by reading it all. One without a body is still in
        // .received_head, which is what std.http.Server.respond resets too.
        if (http.reader.state == .received_head) http.reader.state = .ready;

        var ex: Exchange = undefined;
        ex.init(r, .{
            .method = dartMethod(method).?,
            .version = version,
            .keep_alive = @intFromBool(keep_alive),
            .remote_family = if (peer.getFamily() == .ipv4) 4 else 6,
            .remote_port = peer.getPort(),
            .local_port = local_port,
            .remote_addr = peerBytes(peer),
            .head = &head_copy,
            .head_len = @intCast(head.len),
            .target_off = target_off,
            .target_len = target_len,
            .header_count = index.count,
            .headers = &slots,
            .body = if (body) |b| b.ptr else null,
            .body_len = if (body) |b| b.len else (content_length orelse 0),
            .body_streamed = @intFromBool(stream_body),
            .scratch = if (w.end == 0) w.buffer.ptr else null,
            .scratch_cap = @intCast(w.buffer.len),
        });

        if (r.stop) return writeStatusAndClose(&link, "503 Service Unavailable");

        // A task of its own pumps a streamed body to Dart, so it keeps
        // flowing while the handler runs and while the response goes out.
        // A handler may pipe the body into its response. The pump holds
        // this frame, so it is stopped before any return.
        var pump: ?zio.JoinHandle(bool) = null;
        defer if (pump) |*p| p.cancel();
        if (body_reader) |br| {
            pump = zio.spawn(pumpRequestBody, .{ br, &link, &ex, content_length }) catch return;
        }
        r.ready.push(&ex.node);

        try park(&link, &ex, pump != null);

        defer {
            if (pump) |*p| p.cancel();
            if (ex.resp_head) |p| std.c.free(p);
            if (ex.resp_body) |p| std.c.free(p);
            freeChunks(&ex.in);
        }
        if (ex.upgraded) {
            if (pump) |*p| p.cancel();
            pump = null;
            if (ex.resp_head) |p| try w.writeAll(p[0..ex.resp_head_len]);
            try w.flush();
            pumpWebSocket(&link, &ex);
            return;
        }
        if (ex.hijacked) {
            // The raw reader takes the socket over from the pump.
            if (pump) |*p| p.cancel();
            pump = null;
            pumpRaw(&link, &ex);
            return;
        }
        if (ex.aborted) {
            drainOutbound(&ex);
            return;
        }
        if (ex.resp_streamed) {
            if (ex.resp_head) |p| try w.writeAll(p[0..ex.resp_head_len]);
            const finished = pumpResponseBody(&ex, w);
            if (!finished) return;
        } else if (ex.resp_inline_len != 0) {
            // Dart wrote the whole response into the write buffer, so it
            // goes out as it lies there, under the sweeper's deadline.
            link.setWriteTimeout(.none);
            conn.arm(options.write_timeout_ms);
            w.end = ex.resp_inline_len;
            try w.flush();
            conn.disarm();
            link.setWriteTimeout(inactivity(options.write_timeout_ms));
        } else if (ex.resp_body_len > swept_write_max) {
            if (ex.resp_head) |p| try w.writeAll(p[0..ex.resp_head_len]);
            if (ex.resp_body) |p| try w.writeAll(p[0..@intCast(ex.resp_body_len)]);
            try w.flush();
        } else {
            // A small response goes out under one deadline the sweeper
            // holds, in place of a timeout on every send.
            link.setWriteTimeout(.none);
            conn.arm(options.write_timeout_ms);
            if (ex.resp_head) |p| try w.writeAll(p[0..ex.resp_head_len]);
            if (ex.resp_body) |p| try w.writeAll(p[0..@intCast(ex.resp_body_len)]);
            try w.flush();
            conn.disarm();
            link.setWriteTimeout(inactivity(options.write_timeout_ms));
        }
        // The response is out. A pump still waiting on credit has a body
        // Dart did not finish reading.
        var body_unread = false;
        if (pump) |*p| {
            p.cancel();
            body_unread = !p.join();
            pump = null;
        }

        if (!keep_alive or ex.close_after) return;
        // A body Dart did not finish reading is still on the wire. A modest
        // one is drained so the connection can carry the next request, and
        // so the client is not reset while still sending. A big one is not
        // worth the bandwidth, so close.
        if (body_unread) {
            const left = if (content_length) |len| len else max_discard + 1;
            if (left > max_discard) return;
            const br = body_reader orelse return;
            link.setReadTimeout(inactivity(options.body_timeout_ms));
            _ = br.discardRemaining() catch return;
        }
    }
}

fn pushInbound(ex: *Exchange, chunk: *Chunk) void {
    ex.in_pending += 1;
    ex.in.push(&chunk.node);
    postExchangeEvent(ex);
}

/// Reads a streamed request body chunk by chunk into Dart's inbound queue,
/// at most `in_credit` chunks ahead of Dart. Returns true when the body
/// was read to its end. Returns false when the read failed, or when a
/// cancel or an abort stopped it with the rest of the body unread.
///
/// It reads the socket while the exchange is parked, so it also reports
/// a peer that hung up, as the peer watcher does for a request without a
/// streamed body.
fn pumpRequestBody(br: *std.Io.Reader, link: *Link, ex: *Exchange, content_length: ?u64) bool {
    const gpa = std.heap.c_allocator;
    var remaining: ?u64 = content_length;
    while (true) {
        if (!waitCredit(ex, &ex.closed)) return false;
        const chunk = gpa.create(Chunk) catch return false;
        const buf = std.c.malloc(in_chunk_size) orelse {
            gpa.destroy(chunk);
            return false;
        };
        const data: [*]u8 = @ptrCast(buf);
        const got = br.readSliceShort(data[0..in_chunk_size]) catch {
            std.c.free(buf);
            gpa.destroy(chunk);
            if (link.readCanceled()) return false;
            if (link.readError() != null) ex.view.peer_gone = 1;
            pushLastInbound(ex, false);
            return false;
        };
        if (got == 0) {
            std.c.free(buf);
            gpa.destroy(chunk);
            // EOF before the declared length is a truncated body, not an
            // end. The chunked decoder reports its own truncation as an
            // error above.
            const complete = if (remaining) |left| left == 0 else true;
            if (!complete) ex.view.peer_gone = 1;
            pushLastInbound(ex, complete);
            return complete;
        }
        if (remaining) |left| remaining = left - @min(left, got);
        chunk.* = .{ .ptr = data, .len = got };
        pushInbound(ex, chunk);
    }
}

/// Waits until Dart has taken enough inbound chunks for another, or
/// `stop` is set. False on the stop.
fn waitCredit(ex: *Exchange, stop: *zio.Event) bool {
    while (ex.in_pending >= in_credit) {
        const first = zio.select(.{ .credit = &ex.credit, .stop = stop }) catch return false;
        switch (first) {
            .stop => return false,
            .credit => ex.credit.reset(),
        }
    }
    return true;
}

/// Writes one of Dart's outbound chunks. A failed write is reported once,
/// through the view and an event, and every chunk after it is dropped
/// until Dart reacts. True when the chunk went out.
fn writeOutbound(ex: *Exchange, w: *std.Io.Writer, chunk: *const Chunk, chunked: bool, failed: *bool) bool {
    if (failed.*) return false;
    writeChunk(w, chunk.ptr.?[0..chunk.len], chunked) catch {
        failed.* = true;
        ex.view.write_failed = 1;
        postExchangeEvent(ex);
        return false;
    };
    ex.view.chunks_written += 1;
    return true;
}

/// Writes the outbound chunks Dart hands over until the last one. Returns
/// true when the message finished and the connection can go on, false
/// when it must close.
fn pumpResponseBody(ex: *Exchange, w: *std.Io.Writer) bool {
    var failed = false;
    while (true) {
        while (ex.out.pop()) |node| {
            const chunk: *Chunk = @fieldParentPtr("node", node);
            defer std.heap.c_allocator.destroy(chunk);
            defer if (chunk.ptr) |p| std.c.free(p);
            if (chunk.last) {
                if (!chunk.ok or failed) return false;
                if (ex.resp_chunked) w.writeAll("0\r\n\r\n") catch return false;
                w.flush() catch return false;
                return true;
            }
            if (writeOutbound(ex, w, chunk, ex.resp_chunked, &failed)) postExchangeEvent(ex);
        }
        ex.out_ready.wait() catch return false;
        ex.out_ready.reset();
    }
}

/// A hijacked connection, bytes both ways between the socket and Dart's
/// chunk queues with no framing. A reader task and a writer task do the
/// blocking parts. This one waits for Dart to close its sink or abort,
/// then cancels both so a blocked read or write never holds the
/// connection. The socket closes when this returns.
fn pumpRaw(link: *Link, ex: *Exchange) void {
    link.setReadTimeout(.none);
    var rd = zio.spawn(rawReader, .{ link, ex }) catch return;
    var wr = zio.spawn(rawWriter, .{ link.writer, ex }) catch {
        rd.cancel();
        return;
    };
    ex.closed.wait() catch {};
    rd.cancel();
    wr.cancel();
    freeChunks(&ex.out);
    // The last event. Dart drops its reference to the view on it, so the
    // frame is free to die once this returns.
    postLastEvent(ex);
}

/// Pushes what the socket has, as it comes, at most `in_credit` chunks
/// ahead of Dart. A last chunk marks a clean EOF or a read error.
fn rawReader(link: *Link, ex: *Exchange) void {
    const rd = link.reader;
    while (true) {
        if (!waitCredit(ex, &ex.closed)) return;
        if (rd.bufferedLen() == 0) {
            rd.fillMore() catch |err| {
                if (!link.readCanceled()) pushLastInbound(ex, err == error.EndOfStream);
                return;
            };
        }
        const avail = rd.buffered();
        const n = @min(avail.len, in_chunk_size);
        const chunk = std.heap.c_allocator.create(Chunk) catch return;
        const buf = std.c.malloc(n) orelse {
            std.heap.c_allocator.destroy(chunk);
            return;
        };
        const data: [*]u8 = @ptrCast(buf);
        @memcpy(data[0..n], avail[0..n]);
        rd.toss(n);
        chunk.* = .{ .ptr = data, .len = n };
        pushInbound(ex, chunk);
    }
}

fn pushLastInbound(ex: *Exchange, ok: bool) void {
    const chunk = std.heap.c_allocator.create(Chunk) catch return;
    chunk.* = .{ .ptr = null, .len = 0, .last = true, .ok = ok };
    pushInbound(ex, chunk);
}

/// Writes Dart's chunks as they come. The last one, Dart's sink close,
/// flushes and ends the connection. A failed write is reported once and
/// the rest is dropped until Dart reacts.
fn rawWriter(w: *std.Io.Writer, ex: *Exchange) void {
    var failed = false;
    while (true) {
        while (ex.out.pop()) |node| {
            const chunk: *Chunk = @fieldParentPtr("node", node);
            defer std.heap.c_allocator.destroy(chunk);
            defer if (chunk.ptr) |p| std.c.free(p);
            if (chunk.last) {
                if (!failed) w.flush() catch {};
                ex.closed.set();
                return;
            }
            if (writeOutbound(ex, w, chunk, false, &failed) and !ex.sink_closed) postExchangeEvent(ex);
        }
        const first = zio.select(.{ .ready = &ex.out_ready, .closed = &ex.closed }) catch return;
        switch (first) {
            .closed => return,
            .ready => ex.out_ready.reset(),
        }
    }
}

const WsOpcode = enum(u4) {
    continuation = 0,
    text = 1,
    binary = 2,
    close = 8,
    ping = 9,
    pong = 10,
    _,

    fn isControl(self: WsOpcode) bool {
        return @backingInt(self) >= 8;
    }
};

/// What a chunk Dart takes with relic_ws_read is. Mirrored by `_WsKind`
/// in lib/src/native_web_socket.dart.
const WsKind = enum(u8) {
    text = 1,
    binary = 2,
    /// The peer's close frame, echoed already. Two bytes of code and the
    /// reason, or nothing when it carried no code.
    close = 3,
    /// The peer broke the protocol and got a close frame. Its code and
    /// reason.
    failed = 4,
    /// The connection ended without a close frame.
    dropped = 5,
};

const FrameHead = struct {
    fin: bool,
    opcode: WsOpcode,
    len: u64,
    mask: [4]u8,
};

/// A frame the peer should not have sent, and the close code that answers
/// it. 1002 for a protocol error, 1009 for one too big.
const WsViolation = struct { code: u16, reason: []const u8 };

const FrameHeadResult = union(enum) { head: FrameHead, violation: WsViolation };

fn violation(code: u16, reason: []const u8) FrameHeadResult {
    return .{ .violation = .{ .code = code, .reason = reason } };
}

/// Reads a frame head as a server reads a client's (RFC 6455 5.2): no
/// reserved bit, a known opcode, a mask, a control frame in one piece of
/// at most 125 bytes, a continuation only inside a message and a new
/// message only outside one, and a payload within `max`.
fn readFrameHead(rd: *std.Io.Reader, in_message: bool, max: u64) std.Io.Reader.Error!FrameHeadResult {
    const first = try rd.takeArray(2);
    const b0 = first[0];
    const b1 = first[1];
    if (b0 & 0x70 != 0) return violation(1002, "Reserved bits set");
    const fin = b0 & 0x80 != 0;
    const opcode: WsOpcode = @fromBackingInt(@intCast(@as(u4, @truncate(b0))));
    switch (opcode) {
        .continuation => if (!in_message) return violation(1002, "A continuation frame with no message to continue"),
        .text, .binary => if (in_message) return violation(1002, "A new message while one is still being fragmented"),
        .close, .ping, .pong => if (!fin) return violation(1002, "A control frame cannot be fragmented"),
        _ => return violation(1002, "Unknown opcode"),
    }
    if (b1 & 0x80 == 0) return violation(1002, "A client frame must be masked");
    var len: u64 = b1 & 0x7f;
    if (len >= 126) {
        if (opcode.isControl()) return violation(1002, "A control frame payload is at most 125 bytes");
        if (len == 126) {
            len = std.mem.readInt(u16, try rd.takeArray(2), .big);
        } else {
            const bytes = try rd.takeArray(8);
            if (bytes[0] & 0x80 != 0) return violation(1002, "The most significant bit of a 64-bit length must be 0");
            len = std.mem.readInt(u64, bytes, .big);
        }
    }
    if (len > max) return violation(1009, "Frame too big");
    return .{ .head = .{ .fin = fin, .opcode = opcode, .len = len, .mask = (try rd.takeArray(4)).* } };
}

/// XORs `data` with `mask`, repeated, sixteen bytes at a time.
fn unmask(data: []u8, mask: [4]u8) void {
    const Bytes16 = @Vector(16, u8);
    var pattern: [16]u8 = undefined;
    inline for (0..4) |k| pattern[k * 4 ..][0..4].* = mask;
    const repeated: Bytes16 = pattern;
    var i: usize = 0;
    while (i + 16 <= data.len) : (i += 16) {
        const block: Bytes16 = data[i..][0..16].*;
        data[i..][0..16].* = block ^ repeated;
    }
    for (data[i..], i..) |*b, k| b.* ^= mask[k & 3];
}

/// Writes a server frame. Never masked (RFC 6455 5.1), with the length in
/// the fewest bytes that hold it.
fn writeFrame(w: *std.Io.Writer, opcode: WsOpcode, payload: []const u8) !void {
    var head: [10]u8 = undefined;
    head[0] = 0x80 | @as(u8, @backingInt(opcode));
    var n: usize = 2;
    if (payload.len < 126) {
        head[1] = @intCast(payload.len);
    } else if (payload.len <= 0xffff) {
        head[1] = 126;
        std.mem.writeInt(u16, head[2..4], @intCast(payload.len), .big);
        n = 4;
    } else {
        head[1] = 127;
        std.mem.writeInt(u64, head[2..10], payload.len, .big);
        n = 10;
    }
    try w.writeAll(head[0..n]);
    try w.writeAll(payload);
}

/// Close codes a peer may send (RFC 6455 7.4 and the IANA registry).
/// 1004 is not defined, and 1005, 1006 and 1015 are for local use.
fn isValidCloseCode(code: u16) bool {
    return (code >= 1000 and code <= 1003) or (code >= 1007 and code <= 1014) or (code >= 3000 and code <= 4999);
}

/// A WebSocket connection. A reader task and a writer task run between
/// the socket and Dart's chunk queues until the close handshake is over,
/// the peer is gone, or Dart aborts. The socket closes when this returns.
fn pumpWebSocket(link: *Link, ex: *Exchange) void {
    link.setReadTimeout(.none);
    var rd = zio.spawn(wsReader, .{ link, ex }) catch return;
    var wr = zio.spawn(wsWriter, .{ link.writer, ex }) catch {
        rd.cancel();
        return;
    };
    ex.closed.wait() catch {};
    rd.cancel();
    wr.cancel();
    freeChunks(&ex.out);
    // Dart takes what is queued for it at its next tick, the close among
    // it. The frame holds on for that, unless Dart let go already.
    var rounds: u32 = 0;
    while (!ex.aborted and !ex.in.isEmpty() and rounds < 10) : (rounds += 1) {
        ex.credit.waitTimeout(.fromMilliseconds(ws_drain_wait_ms / 10)) catch |err| {
            if (err == error.Canceled) break;
        };
        ex.credit.reset();
    }
    postLastEvent(ex);
}

/// Reads the peer's frames. Answers pings, counts pongs, assembles
/// messages, checks text, and hands each message to Dart. Stops at the
/// peer's close frame, which it echoes, at the end of the connection, or
/// at a violation, which it answers with a close frame. The writer learns
/// through `peer_close` that nothing more comes.
fn wsReader(link: *Link, ex: *Exchange) void {
    defer ex.peer_close.set();
    const rd = link.reader;
    // Plain malloc for a byte list, so Dart frees a message with relic_free.
    const gpa = std.heap.c_allocator;
    var message: std.ArrayListUnmanaged(u8) = .empty;
    defer message.deinit(gpa);
    var message_opcode: ?WsOpcode = null;
    const max: u64 = ex.ws_max_message;
    while (true) {
        const result = readFrameHead(rd, message_opcode != null, max) catch return wsReadEnded(link, ex);
        const head = switch (result) {
            .head => |h| h,
            .violation => |v| return wsFail(ex, v.code, v.reason),
        };
        if (head.opcode.isControl()) {
            var buf: [ws_control_max]u8 = undefined;
            const payload = buf[0..@intCast(head.len)];
            rd.readSliceAll(payload) catch return wsReadEnded(link, ex);
            unmask(payload, head.mask);
            switch (head.opcode) {
                .ping => if (!ex.ws_close_sent) pushOutbound(ex, .pong, payload),
                .pong => ex.view.ws_pongs +%= 1,
                .close => return wsPeerClose(ex, payload),
                else => unreachable,
            }
            continue;
        }
        if (message.items.len + head.len > max) return wsFail(ex, 1009, "Message too big");
        const opcode = message_opcode orelse head.opcode;
        message_opcode = opcode;
        const len: usize = @intCast(head.len);
        message.ensureUnusedCapacity(gpa, len) catch return wsFail(ex, 1011, "Out of memory");
        const slot = message.unusedCapacitySlice()[0..len];
        rd.readSliceAll(slot) catch return wsReadEnded(link, ex);
        unmask(slot, head.mask);
        message.items.len += len;
        if (!head.fin) continue;
        message_opcode = null;
        if (opcode == .text and !std.unicode.utf8ValidateSlice(message.items)) return wsFail(ex, 1007, "Text is not valid UTF-8");
        if (ex.ws_close_sent) {
            message.clearRetainingCapacity();
            continue;
        }
        if (!waitCredit(ex, &ex.closed)) return;
        const kind: WsKind = if (opcode == .text) .text else .binary;
        if (message.items.len == 0) {
            pushWsInbound(ex, kind, null, 0);
            continue;
        }
        const owned = message.toOwnedSlice(gpa) catch return wsFail(ex, 1011, "Out of memory");
        pushWsInbound(ex, kind, owned.ptr, owned.len);
    }
}

/// The connection ended, or the read was cancelled, inside a frame.
fn wsReadEnded(link: *Link, ex: *Exchange) void {
    if (link.readCanceled()) return;
    wsDropped(ex);
}

/// The connection ended without a close frame. Dart hears 1006, unless a
/// close of this side's was on its way, and the connection ends.
fn wsDropped(ex: *Exchange) void {
    if (!ex.ws_close_sent) pushWsInbound(ex, .dropped, null, 0);
    ex.closed.set();
}

/// The peer's close frame. A code is two bytes and one the peer may send,
/// and a reason is UTF-8. The code goes back in a close frame, and Dart
/// gets the code and the reason.
fn wsPeerClose(ex: *Exchange, payload: []const u8) void {
    if (payload.len == 1) return wsFail(ex, 1002, "A close code is two bytes");
    if (payload.len >= 2) {
        const code = std.mem.readInt(u16, payload[0..2], .big);
        if (!isValidCloseCode(code)) {
            var buf: [32]u8 = undefined;
            const reason: []const u8 = std.fmt.bufPrint(&buf, "Close code {d}", .{code}) catch "Close code";
            return wsFail(ex, 1002, reason);
        }
        if (!std.unicode.utf8ValidateSlice(payload[2..])) return wsFail(ex, 1007, "Close reason is not valid UTF-8");
    }
    // Either the peer answered this side's close, or it closes first and
    // gets its code back.
    if (ex.ws_close_sent) return;
    ex.ws_close_sent = true;
    pushOutbound(ex, .close, payload[0..@min(payload.len, 2)]);
    pushWsInboundCopy(ex, .close, payload);
}

/// Answers a violation with a close frame carrying `code`, tells Dart,
/// and stops reading. It does not wait for the peer's answer.
fn wsFail(ex: *Exchange, code: u16, reason: []const u8) void {
    if (ex.ws_close_sent) return;
    ex.ws_close_sent = true;
    var payload: [2 + ws_control_max]u8 = undefined;
    std.mem.writeInt(u16, payload[0..2], code, .big);
    const n = @min(reason.len, ws_control_max - 2);
    @memcpy(payload[2 .. 2 + n], reason[0..n]);
    pushOutbound(ex, .close, payload[0 .. 2 + n]);
    pushWsInboundCopy(ex, .failed, payload[0 .. 2 + n]);
}

/// Queues a frame for the writer, with its own copy of `payload`.
fn pushOutbound(ex: *Exchange, opcode: WsOpcode, payload: []const u8) void {
    const chunk = std.heap.c_allocator.create(Chunk) catch return;
    var ptr: ?[*]u8 = null;
    if (payload.len > 0) {
        const buf = std.c.malloc(payload.len) orelse {
            std.heap.c_allocator.destroy(chunk);
            return;
        };
        const data: [*]u8 = @ptrCast(buf);
        @memcpy(data[0..payload.len], payload);
        ptr = data;
    }
    chunk.* = .{ .ptr = ptr, .len = payload.len, .kind = @backingInt(opcode) };
    ex.out.push(&chunk.node);
    ex.out_ready.set();
}

/// Hands Dart a message it frees with relic_free, or an empty one.
fn pushWsInbound(ex: *Exchange, kind: WsKind, ptr: ?[*]u8, len: usize) void {
    const chunk = std.heap.c_allocator.create(Chunk) catch {
        if (ptr) |p| std.c.free(p);
        return;
    };
    chunk.* = .{ .ptr = ptr, .len = len, .kind = @backingInt(kind) };
    pushInbound(ex, chunk);
}

fn pushWsInboundCopy(ex: *Exchange, kind: WsKind, payload: []const u8) void {
    if (payload.len == 0) return pushWsInbound(ex, kind, null, 0);
    const buf = std.c.malloc(payload.len) orelse return;
    const data: [*]u8 = @ptrCast(buf);
    @memcpy(data[0..payload.len], payload);
    pushWsInbound(ex, kind, data, payload.len);
}

/// Writes what is queued for the peer: Dart's messages and pings, the
/// pongs, and a close frame, which is the last. After it the writer waits
/// ws_close_wait_ms at most for the peer's own close frame, and the
/// connection ends.
fn wsWriter(w: *std.Io.Writer, ex: *Exchange) void {
    while (true) {
        while (ex.out.pop()) |node| {
            const chunk: *Chunk = @fieldParentPtr("node", node);
            defer std.heap.c_allocator.destroy(chunk);
            defer if (chunk.ptr) |p| std.c.free(p);
            const payload: []const u8 = if (chunk.ptr) |p| p[0..chunk.len] else "";
            const opcode: WsOpcode = @fromBackingInt(@intCast(@as(u4, @truncate(chunk.kind))));
            writeFrame(w, opcode, payload) catch return wsWriteFailed(ex);
            if (opcode != .close) continue;
            w.flush() catch return wsWriteFailed(ex);
            ex.peer_close.waitTimeout(.fromMilliseconds(ws_close_wait_ms)) catch {};
            ex.closed.set();
            return;
        }
        w.flush() catch return wsWriteFailed(ex);
        const first = zio.select(.{ .ready = &ex.out_ready, .closed = &ex.closed }) catch return;
        switch (first) {
            .closed => return,
            .ready => ex.out_ready.reset(),
        }
    }
}

/// A write failed, so the peer stopped reading. The connection ends, and
/// Dart hears 1006 at the last event.
fn wsWriteFailed(ex: *Exchange) void {
    ex.view.write_failed = 1;
    ex.closed.set();
}

fn writeChunk(w: *std.Io.Writer, data: []const u8, chunked: bool) !void {
    if (chunked) {
        try w.print("{x}\r\n", .{data.len});
        try w.writeAll(data);
        try w.writeAll("\r\n");
    } else {
        try w.writeAll(data);
    }
    try w.flush();
}

/// Frees whatever Dart still pushes after an abort, until its last chunk.
/// Dart always pushes a last chunk once it started streaming, so this
/// returns.
fn drainOutbound(ex: *Exchange) void {
    if (!ex.resp_streamed) return;
    while (true) {
        while (ex.out.pop()) |node| {
            const chunk: *Chunk = @fieldParentPtr("node", node);
            const last = chunk.last;
            if (chunk.ptr) |p| std.c.free(p);
            std.heap.c_allocator.destroy(chunk);
            if (last) return;
        }
        ex.out_ready.wait() catch return;
        ex.out_ready.reset();
    }
}

fn freeChunks(queue: *Fifo) void {
    while (queue.pop()) |node| {
        const chunk: *Chunk = @fieldParentPtr("node", node);
        if (chunk.ptr) |p| std.c.free(p);
        std.heap.c_allocator.destroy(chunk);
    }
}

/// Waits for Dart to answer the exchange.
///
/// Dart holds a pointer into the task's stack frame until it responds. A
/// cancel reaches this wait only from relic_reactor_destroy, after Dart
/// aborted every exchange it still held, so the frame can die then.
///
/// A handler that asks for `cancelled` makes Dart set `watch`. From then
/// on a watcher task reads the socket, so a peer that hangs up is noticed
/// and reported while the handler still runs. Nothing is spent on
/// requests whose handler never asks.
fn park(link: *Link, ex: *Exchange, pumping: bool) !void {
    if (ex.done.isSet()) return;
    // A body pump reads the socket already, and reports the peer going
    // away itself.
    if (pumping) return ex.done.wait();
    const first = try zio.select(.{ .done = &ex.done, .watch = &ex.watch });
    switch (first) {
        .done => {},
        .watch => {
            link.setReadTimeout(.none);
            var watcher: ?zio.JoinHandle(void) = zio.spawn(peerWatcher, .{ link, ex }) catch null;
            defer if (watcher) |*wt| wt.cancel();
            try ex.done.wait();
        },
    }
}

/// Reads into the connection's buffer while the task is parked. EOF means
/// the peer hung up. Data means a pipelined request, which stays buffered
/// for the next receiveHead. A cancel from the task ends it either way.
fn peerWatcher(link: *Link, ex: *Exchange) void {
    link.reader.fillMore() catch |err| {
        if (err == error.EndOfStream) {
            ex.view.peer_gone = 1;
            postExchangeEvent(ex);
        }
    };
}

fn peerBytes(peer: zio.net.IpAddress) [16]u8 {
    var out: [16]u8 = @splat(0);
    switch (peer.getFamily()) {
        .ipv4 => @memcpy(out[0..4], std.mem.asBytes(&peer.in.addr)),
        .ipv6 => @memcpy(out[0..16], &peer.in6.addr),
    }
    return out;
}

fn off(base: []const u8, s: []const u8) u32 {
    return @intCast(@intFromPtr(s.ptr) - @intFromPtr(base.ptr));
}

const ParseHeadError = error{ TooManyHeaders, MalformedHead };

const Head = std.http.Server.Request.Head;

/// What the head says. The request line, the fields that frame the
/// message, and where every header field sits.
const ParsedHead = struct { head: Head, count: u32, host_slot: i32 };

/// Parses the head in one pass, copies it into `head_copy` and fills
/// `slots` with where each header field sits in it.
///
/// The head lives in the reader buffer, which the body read reuses, so
/// the copy is what Dart gets. Offsets computed against the original
/// hold for the copy.
///
/// Every line must end in CRLF, the head in an empty line, and every
/// field line must hold a colon and start with neither space nor tab
/// (RFC 9112 5.1 and 5.2). The std.http head parser accepts a bare LF
/// as a terminator and can end a head one line early.
///
/// A field name must be a token, which rules out whitespace before the
/// colon, and a field value must hold no control character but a tab
/// (RFC 9110 5.1 and 5.5). A NUL or a bare CR that reached a handler
/// could be echoed into a response or passed upstream as a line break.
///
/// The request line and the framing fields read as
/// `std.http.Server.Request.Head.parse` reads them, which a test holds
/// this to. That parser is not used. It splits the head with a two-byte
/// sequence search and compares every field name against six names,
/// which sampled at four percent of the isolate.
fn parseHead(bytes: []const u8, head_copy: []u8, slots: []HeaderSlot) ParseHeadError!ParsedHead {
    if (!std.mem.endsWith(u8, bytes, "\r\n\r\n")) return error.MalformedHead;
    var head: Head = undefined;
    var n: u32 = 0;
    var host_slot: i32 = -1;
    var transfer_encoded = false;
    var line_start: usize = 0;
    while (std.mem.findScalarPos(u8, bytes, line_start, '\n')) |lf| : (line_start = lf + 1) {
        if (lf == 0 or bytes[lf - 1] != '\r') return error.MalformedHead;
        const line = bytes[line_start .. lf - 1];
        if (line_start == 0) {
            head = try parseRequestLine(line);
            continue;
        }
        if (line.len == 0) continue;
        if (line[0] == ' ' or line[0] == '\t') return error.MalformedHead;
        const colon = std.mem.findScalar(u8, line, ':') orelse return error.MalformedHead;
        const name = line[0..colon];
        if (!isToken(name) or hasControl(line[colon + 1 ..])) return error.MalformedHead;
        if (n == slots.len) return error.TooManyHeaders;
        const value = std.mem.trim(u8, line[colon + 1 ..], " \t");
        const id = header_names.lookup(name);
        slots[n] = .{
            .name_off = @intCast(line_start),
            .name_id = id,
            .value_off = @intCast(line_start + colon + 1 + (value.ptr - line[colon + 1 ..].ptr)),
            .value_len = @intCast(value.len),
        };
        switch (id) {
            header_names.host => {
                // A second Host gets a 400 (RFC 9112 3.2). A proxy in
                // front and this server could otherwise route on
                // different ones.
                if (host_slot >= 0) return error.MalformedHead;
                host_slot = @intCast(n);
            },
            header_names.expect => head.expect = value,
            header_names.connection => head.keep_alive = switch (head.version) {
                .@"HTTP/1.1" => !connectionHas(value, "close"),
                .@"HTTP/1.0" => connectionHas(value, "keep-alive"),
            },
            header_names.content_type => head.content_type = value,
            header_names.content_length => {
                if (head.content_length != null) return error.MalformedHead;
                head.content_length = parseContentLength(value) orelse return error.MalformedHead;
            },
            header_names.content_encoding => {
                if (head.transfer_compression != .identity) return error.MalformedHead;
                head.transfer_compression = std.http.ContentEncoding.fromString(std.mem.trim(u8, value, " ")) orelse
                    return error.MalformedHead;
            },
            header_names.transfer_encoding => {
                transfer_encoded = true;
                try parseTransferEncoding(&head, value);
            },
            else => {},
        }
        n += 1;
    }
    // HTTP/1.1 requires Host (RFC 9112 3.2). An HTTP/1.0 request without
    // one resolves to the listener address on the Dart side.
    if (head.version == .@"HTTP/1.1" and host_slot < 0) return error.MalformedHead;
    // Transfer-Encoding beside Content-Length gets a 400 (RFC 9112 6.3).
    // A proxy in front and this server could otherwise frame the body
    // differently, which is request smuggling.
    if (transfer_encoded and head.content_length != null) return error.MalformedHead;
    @memcpy(head_copy[0..bytes.len], bytes);
    return .{ .head = head, .count = n, .host_slot = host_slot };
}

/// The index of `method` in `_methods` of lib/src/native_adapter.dart, or
/// null for a method relic has no Method for.
fn dartMethod(method: std.http.Method) ?u8 {
    return switch (method) {
        .GET => 0,
        .HEAD => 1,
        .POST => 2,
        .PUT => 3,
        .DELETE => 4,
        .CONNECT => 5,
        .OPTIONS => 6,
        .TRACE => 7,
        .PATCH => 8,
        .QUERY => null,
    };
}

/// `METHOD target HTTP/1.x`, with the target taken as everything between
/// the first space and the last.
fn parseRequestLine(line: []const u8) ParseHeadError!Head {
    if (line.len < 10) return error.MalformedHead;
    const method_end = std.mem.findScalar(u8, line, ' ') orelse return error.MalformedHead;
    const method = std.meta.stringToEnum(std.http.Method, line[0..method_end]) orelse return error.MalformedHead;
    if (dartMethod(method) == null) return error.MalformedHead;
    const version_start = std.mem.findScalarLast(u8, line, ' ') orelse return error.MalformedHead;
    if (version_start == method_end) return error.MalformedHead;
    const version_text = line[version_start + 1 ..];
    const version: std.http.Version = if (std.mem.eql(u8, version_text, "HTTP/1.1"))
        .@"HTTP/1.1"
    else if (std.mem.eql(u8, version_text, "HTTP/1.0"))
        .@"HTTP/1.0"
    else
        return error.MalformedHead;
    const target = line[method_end + 1 .. version_start];
    if (!isTarget(target)) return error.MalformedHead;
    return .{
        .method = method,
        .target = target,
        .version = version,
        .expect = null,
        .content_type = null,
        .content_length = null,
        .transfer_encoding = .none,
        .transfer_compression = .identity,
        .keep_alive = version == .@"HTTP/1.1",
    };
}

/// One transfer coding, or a content coding followed by one, as
/// std.http reads the field: `chunked`, `gzip, chunked`.
fn parseTransferEncoding(head: *Head, value: []const u8) ParseHeadError!void {
    var codings = std.mem.splitBackwardsScalar(u8, value, ',');
    const last = codings.first();
    var next: ?[]const u8 = last;
    if (std.meta.stringToEnum(std.http.TransferEncoding, std.mem.trim(u8, last, " "))) |transfer| {
        if (head.transfer_encoding != .none) return error.MalformedHead;
        head.transfer_encoding = transfer;
        next = codings.next();
    }
    if (next) |second| {
        const compression = std.http.ContentEncoding.fromString(std.mem.trim(u8, second, " ")) orelse
            return error.MalformedHead;
        if (head.transfer_compression != .identity) return error.MalformedHead;
        head.transfer_compression = compression;
    }
    if (codings.next() != null) return error.MalformedHead;
}

/// Whether `token` is among the comma-separated tokens of a Connection
/// field (RFC 9110 7.6.1), compared ASCII case-insensitively. std.http
/// reads the field as one token, so `close, TE` keeps its connection
/// alive there and not here.
fn connectionHas(value: []const u8, token: []const u8) bool {
    var tokens = std.mem.splitScalar(u8, value, ',');
    while (tokens.next()) |candidate| {
        if (std.ascii.eqlIgnoreCase(std.mem.trim(u8, candidate, " \t"), token)) return true;
    }
    return false;
}

/// The tchar set of RFC 9110 5.6.2.
const token_chars = blk: {
    var table: [256]bool = @splat(false);
    for ("!#$%&'*+-.^_`|~0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ") |c| table[c] = true;
    break :blk table;
};

fn isToken(name: []const u8) bool {
    if (name.len == 0) return false;
    for (name) |c| {
        if (!token_chars[c]) return false;
    }
    return true;
}

/// A Content-Length value, 1*DIGIT (RFC 9110 8.6). std.fmt.parseInt
/// would also take a sign and `_` separators, which a proxy in front
/// reads as another length or not at all.
fn parseContentLength(value: []const u8) ?u64 {
    if (value.len == 0) return null;
    var length: u64 = 0;
    for (value) |c| {
        if (c < '0' or c > '9') return null;
        length = std.math.mul(u64, length, 10) catch return null;
        length = std.math.add(u64, length, c - '0') catch return null;
    }
    return length;
}

/// A request target is at least one byte, all of them visible ASCII
/// (RFC 9112 3 over RFC 3986). parseRequestLine splits the line on its
/// first and last space, so a space in between would otherwise end up in
/// here.
fn isTarget(bytes: []const u8) bool {
    if (bytes.len == 0) return false;
    const Bytes16 = @Vector(16, u8);
    var i: usize = 0;
    while (i + 16 <= bytes.len) : (i += 16) {
        const block: Bytes16 = bytes[i..][0..16].*;
        const low: u16 = @bitCast(block <= @as(Bytes16, @splat(' ')));
        const high: u16 = @bitCast(block >= @as(Bytes16, @splat(0x7f)));
        if (low | high != 0) return false;
    }
    for (bytes[i..]) |c| {
        if (c <= ' ' or c >= 0x7f) return false;
    }
    return true;
}

/// Whether `bytes` holds a control character other than a tab: anything
/// below a space, or DEL.
fn hasControl(bytes: []const u8) bool {
    const Bytes16 = @Vector(16, u8);
    var i: usize = 0;
    while (i + 16 <= bytes.len) : (i += 16) {
        const block: Bytes16 = bytes[i..][0..16].*;
        const low: u16 = @bitCast(block < @as(Bytes16, @splat(' ')));
        const tab: u16 = @bitCast(block == @as(Bytes16, @splat('\t')));
        const del: u16 = @bitCast(block == @as(Bytes16, @splat(0x7f)));
        if ((low & ~tab) | del != 0) return true;
    }
    for (bytes[i..]) |c| {
        if ((c < ' ' and c != '\t') or c == 0x7f) return true;
    }
    return false;
}

/// The body reader for a request that declares a body, after answering
/// an `Expect: 100-continue`. Any method may carry a body here. The
/// std.http.Server reader hands back an empty one for GET and DELETE,
/// which would leave the declared bytes in the stream as the next head.
fn openBody(req: *std.http.Server.Request, buffer: []u8) std.http.Server.Request.ExpectContinueError!*std.Io.Reader {
    const flush = req.head.expect != null;
    try req.writeExpectContinue();
    if (flush) try req.server.out.flush();
    return req.server.reader.bodyReader(buffer, req.head.transfer_encoding, req.head.content_length);
}

var registry_lock: zio.os.Mutex = .{};
/// One Server per group, shared by the isolates that attach.
var registry: std.StringHashMapUnmanaged(*Server) = .empty;

/// Every failure is an error, so the errdefers run. They do not on a
/// `return null`.
fn createServer(group: ?[]const u8, ip: []const u8, port: u16, options: Options) !*Server {
    const gpa = std.heap.c_allocator;
    const capacity = @max(options.reactor_capacity, 1);
    const address = try zio.net.IpAddress.parseIp(ip, port);
    const srv = try gpa.create(Server);
    errdefer gpa.destroy(srv);
    const reactors = try gpa.alloc(?*Reactor, capacity);
    errdefer gpa.free(reactors);
    @memset(reactors, null);
    const owned_group: ?[]u8 = if (group) |g| try gpa.dupe(u8, g) else null;
    errdefer if (owned_group) |g| gpa.free(g);
    srv.* = .{
        .gpa = gpa,
        .reactors = reactors,
        .options = options,
        .group = owned_group,
        .address = address,
    };
    srv.thread = try std.Thread.spawn(.{}, Server.run, .{srv});
    srv.bound.wait();
    if (srv.bind_failed.load(.acquire)) {
        srv.thread.join();
        return error.BindFailed;
    }
    return srv;
}

const ipv6_loopback = [16]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 };

/// Connects to the listener and hangs up, so an accept the acceptor is
/// blocked in returns and the loop sees the stop flag. An unspecified
/// listen address is reached through loopback. A SYN the kernel drops on
/// a full backlog leaves the accept to its timeout.
fn pokeAcceptor(srv: *Server) void {
    const net = zio.os.net;
    var target = srv.address;
    const ipv6 = target.getFamily() == .ipv6;
    if (target.isUnspecified()) {
        target = if (ipv6)
            zio.net.IpAddress.initIp6(ipv6_loopback, 0, 0, 0)
        else
            zio.net.IpAddress.initIp4(.{ 127, 0, 0, 1 }, 0);
    }
    target.setPort(srv.bound_port.load(.acquire));
    const fd = libc.socket(if (ipv6) net.AF.INET6 else net.AF.INET, net.SOCK.STREAM, 0);
    if (fd < 0) return;
    defer _ = libc.close(fd);
    const len: u32 = if (ipv6) @sizeOf(net.sockaddr.in6) else @sizeOf(net.sockaddr.in);
    _ = libc.connect(fd, &target.any, len);
}

/// Stops accepting, joins the thread and frees the server. Assumes every
/// reactor has detached.
fn destroyServer(srv: *Server) void {
    srv.stop.store(true, .release);
    pokeAcceptor(srv);
    srv.thread.join();
    const gpa = srv.gpa;
    if (srv.group) |g| gpa.free(g);
    gpa.free(srv.reactors);
    gpa.destroy(srv);
}

export fn relic_init_dart_api(data: ?*anyopaque) isize {
    // Every isolate that binds calls this. Dart_InitializeApiDL fills the
    // same function pointers each time, so repeats are harmless.
    return dart.Dart_InitializeApiDL(data);
}

/// Creates the server for `group`, or returns the one that exists. With a
/// null group the server is not registered and belongs to the caller
/// alone. Blocks until the listener is bound. Null when binding failed.
export fn relic_server_bind(
    group: ?[*:0]const u8,
    ip: [*:0]const u8,
    port: u16,
    options: *const Options,
) ?*Server {
    const key: ?[]const u8 = if (group) |g| std.mem.span(g) else null;
    registry_lock.lock();
    defer registry_lock.unlock();
    if (key) |k| {
        if (registry.get(k)) |existing| return existing;
    }
    const srv = createServer(key, std.mem.span(ip), port, options.*) catch return null;
    if (srv.group) |g| {
        registry.put(std.heap.c_allocator, g, srv) catch {
            destroyServer(srv);
            return null;
        };
    }
    return srv;
}

export fn relic_server_port(srv: *Server) u16 {
    return srv.bound_port.load(.acquire);
}

/// Creates the reactor for the calling isolate, on the calling thread,
/// and attaches it to `srv`. `port` receives the wake messages. Null when
/// every slot is taken or the runtime could not start.
export fn relic_reactor_create(srv: *Server, port: dart.Dart_Port_DL) ?*Reactor {
    return createReactor(srv, port) catch null;
}

/// Every failure is an error, so the errdefers run. They do not on a
/// `return null`.
fn createReactor(srv: *Server, port: dart.Dart_Port_DL) !*Reactor {
    const gpa = std.heap.c_allocator;
    const r = try gpa.create(Reactor);
    errdefer gpa.destroy(r);
    const rt = try zio.Runtime.init(gpa, .{ .executors = .exact(1) });
    errdefer rt.deinit();
    r.* = .{ .gpa = gpa, .server = srv, .slot = no_slot, .port = port, .rt = rt };
    r.incoming.init();
    if (!r.poke.init()) return error.PokeFailed;
    errdefer r.poke.deinit();
    r.waiter = try std.Thread.spawn(.{}, waiterThread, .{r});
    errdefer {
        r.waiter_stop.store(true, .release);
        r.waiter_arm.set();
        r.waiter.join();
    }

    srv.attach_lock.lock();
    defer srv.attach_lock.unlock();
    for (srv.reactors, 0..) |*slot, i| {
        if (slot.* != null) continue;
        r.slot = @intCast(i);
        slot.* = r;
        srv.attached_count += 1;
        return r;
    }
    return error.ServerFull;
}

/// Takes the reactor out of service ahead of destroy. The acceptor passes
/// it over, its idle connections close, and its other connections close
/// after their current response, with a 503 for a request that arrives
/// after this. The listener closes with the last accepting reactor.
export fn relic_reactor_stop(r: *Reactor) void {
    r.stop = true;
    r.accepting.store(false, .release);
    var next = r.conns.first;
    while (next) |node| : (next = node.next) {
        const conn: *Conn = @fieldParentPtr("node", node);
        if (conn.idle) conn.task.cancel();
    }
    const srv = r.server;
    srv.attach_lock.lock();
    defer srv.attach_lock.unlock();
    for (srv.reactors) |maybe| {
        const other = maybe orelse continue;
        if (other.accepting.load(.acquire)) return;
    }
    srv.stop.store(true, .release);
    pokeAcceptor(srv);
}

/// Detaches the reactor, cancels its connections and frees it. Assumes
/// Dart has aborted every exchange it still held. The last detach stops
/// the server, which blocks until its thread has joined, and frees it.
/// Both pointers are dead afterwards.
export fn relic_reactor_destroy(r: *Reactor) void {
    const srv = r.server;
    var last = false;
    {
        srv.attach_lock.lock();
        defer srv.attach_lock.unlock();
        srv.reactors[r.slot] = null;
        srv.attached_count -= 1;
        last = srv.attached_count == 0;
    }
    r.stop = true;
    r.waiter_stop.store(true, .release);
    r.waiter_arm.set();
    r.pokeWaiter();
    r.waiter.join();
    r.poke.deinit();
    // Sockets that arrived after the last tick never got a task.
    while (r.incoming.pop()) |node| {
        const inc: *Incoming = @fieldParentPtr("node", node);
        inc.stream.close();
        r.gpa.destroy(inc);
    }
    // One tick binds the executor to this thread. Then the main task
    // blocks in the cancel, which runs the loop until every connection
    // task has unwound.
    _ = r.rt.main_executor.tick(.zero) catch {};
    r.group.cancel();
    r.rt.deinit();
    r.events.deinit(r.gpa);
    const gpa = r.gpa;
    gpa.destroy(r);

    if (!last) return;
    if (srv.group) |g| {
        registry_lock.lock();
        defer registry_lock.unlock();
        _ = registry.remove(g);
    }
    destroyServer(srv);
}

/// One pass of the reactor: runs its tasks, polls the loop for at most
/// `wait_ms`, takes in the sockets the acceptor handed over, and returns
/// up to `max` exchanges that are ready for a handler. Afterwards
/// relic_reactor_pending says whether to call again at once.
export fn relic_reactor_tick(r: *Reactor, wait_ms: u32, out: [*]*ExchangeView, max: u32) u32 {
    r.pending = r.rt.main_executor.tick(.fromMilliseconds(wait_ms)) catch false;
    r.drainIncoming();
    var n: u32 = 0;
    while (n < max) : (n += 1) {
        const node = r.ready.pop() orelse break;
        out[n] = &@as(*Exchange, @fieldParentPtr("node", node)).view;
    }
    if (!r.ready.isEmpty()) r.pending = true;
    return n;
}

/// Whether the last tick left work behind: ready tasks, sockets just
/// spawned, or exchanges that did not fit in `out`.
export fn relic_reactor_pending(r: *Reactor) bool {
    return r.pending;
}

/// Takes up to `max` addresses of exchanges with an event since the last
/// call. The same address may appear more than once. The low bit is set
/// on the last event of a hijacked connection, whose view Dart must not
/// read.
export fn relic_reactor_events(r: *Reactor, out: [*]usize, max: u32) u32 {
    var n: u32 = 0;
    while (n < max and r.events_taken < r.events.items.len) : (n += 1) {
        out[n] = r.events.items[r.events_taken];
        r.events_taken += 1;
    }
    if (r.events_taken == r.events.items.len) {
        r.events.clearRetainingCapacity();
        r.events_taken = 0;
    }
    return n;
}

/// Arms the waiter, which posts one message to the isolate's port once
/// the loop has events or its next timer is due. Called when a tick left
/// nothing to do.
export fn relic_reactor_wait(r: *Reactor) void {
    const loop = &r.rt.main_executor.loop;
    var until: i64 = std.math.maxInt(i64);
    if (loop.nextTimerDeadline()) |d| {
        until = nowMs() + @as(i64, @intCast(d.toMilliseconds())) + 1;
    }
    if (r.waiter_armed.load(.acquire)) {
        // Already waiting. A deadline earlier than the one it waits with
        // reaches it through the pipe. The spurious message that follows
        // costs one tick.
        if (until < r.waiter_until.load(.acquire)) r.pokeWaiter();
        return;
    }
    r.waiter_until.store(until, .release);
    r.waiter_armed.store(true, .release);
    r.waiter_arm.set();
}

/// Loop time in milliseconds, the clock the waiter's deadline is on.
fn nowMs() i64 {
    return @divFloor(@as(i64, @intCast(zio.now().toNanoseconds())), std.time.ns_per_ms);
}

/// The reactor's slot in its server, which `Stats.first_attached` refers to.
export fn relic_reactor_slot(r: *Reactor) u32 {
    return r.slot;
}

/// Ownership of `head` and `body`, malloc'd by Dart, passes to native.
export fn relic_respond(
    v: *ExchangeView,
    head: [*]u8,
    head_len: u32,
    body: ?[*]u8,
    body_len: u64,
    close_after: bool,
) void {
    const ex: *Exchange = @fieldParentPtr("view", v);
    ex.resp_head = head;
    ex.resp_head_len = head_len;
    ex.resp_body = body;
    ex.resp_body_len = body_len;
    ex.close_after = close_after;
    ex.done.set();
}

/// Answers with the `len` bytes Dart wrote into the view's `scratch`,
/// head and body back to back.
export fn relic_respond_inline(v: *ExchangeView, len: u32, close_after: bool) void {
    const ex: *Exchange = @fieldParentPtr("view", v);
    ex.resp_inline_len = len;
    ex.close_after = close_after;
    ex.done.set();
}

/// Like relic_respond, but the body follows through relic_write_chunk and
/// ends with relic_finish_stream. `chunked` selects chunked transfer
/// coding on the wire, for a body of unknown length.
export fn relic_respond_stream(
    v: *ExchangeView,
    head: [*]u8,
    head_len: u32,
    close_after: bool,
    chunked: bool,
) void {
    const ex: *Exchange = @fieldParentPtr("view", v);
    ex.resp_head = head;
    ex.resp_head_len = head_len;
    ex.resp_streamed = true;
    ex.resp_chunked = chunked;
    ex.close_after = close_after;
    ex.done.set();
}

/// Hands over one chunk of a streamed response. Ownership of `data`,
/// malloc'd by Dart, passes to native. Returns false when the node could
/// not be allocated, in which case `data` still belongs to Dart.
export fn relic_write_chunk(v: *ExchangeView, data: [*]u8, len: usize) bool {
    const ex: *Exchange = @fieldParentPtr("view", v);
    const chunk = std.heap.c_allocator.create(Chunk) catch return false;
    chunk.* = .{ .ptr = data, .len = len };
    ex.out.push(&chunk.node);
    ex.out_ready.set();
    return true;
}

/// Ends a streamed response. `ok` false drops the connection instead of
/// finishing the message, for a body stream that failed.
export fn relic_finish_stream(v: *ExchangeView, ok: bool) void {
    const ex: *Exchange = @fieldParentPtr("view", v);
    if (ex.hijacked) ex.sink_closed = true;
    const chunk = std.heap.c_allocator.create(Chunk) catch {
        // Out of memory. Failing the connection is the best that is left.
        v.write_failed = 1;
        return;
    };
    chunk.* = .{ .ptr = null, .len = 0, .last = true, .ok = ok };
    ex.out.push(&chunk.node);
    ex.out_ready.set();
}

/// Takes the next inbound chunk of a streamed request body. Returns 0 when
/// none is queued. `data` and `len` describe the chunk, which Dart frees
/// with relic_free. A last chunk has `len` 0 and a null `data`, and
/// `status` is then 1 for a clean end or 2 for a read failure.
export fn relic_read_chunk(v: *ExchangeView, data: *?[*]u8, len: *usize, status: *u8) u8 {
    const ex: *Exchange = @fieldParentPtr("view", v);
    const node = ex.in.pop() orelse return 0;
    const chunk: *Chunk = @fieldParentPtr("node", node);
    defer std.heap.c_allocator.destroy(chunk);
    data.* = chunk.ptr;
    len.* = chunk.len;
    status.* = if (!chunk.last) 0 else if (chunk.ok) 1 else 2;
    // Dart consumed one, so the task may read one more ahead.
    ex.in_pending -= 1;
    ex.credit.set();
    return 1;
}

/// Asks the task to watch the connection for EOF while the exchange is
/// parked. An event follows, with `peer_gone` set.
export fn relic_watch(v: *ExchangeView) void {
    const ex: *Exchange = @fieldParentPtr("view", v);
    ex.watch.set();
}

/// Drops the connection without a response. Frees nothing Dart owns.
export fn relic_abort(v: *ExchangeView) void {
    const ex: *Exchange = @fieldParentPtr("view", v);
    ex.aborted = true;
    ex.done.set();
    ex.closed.set();
}

/// Takes the connection as a raw byte channel. Bytes from the peer come
/// through relic_read_chunk, bytes to the peer go through relic_write_chunk,
/// and relic_finish_stream closes the connection once they are written.
/// Nothing is written by the server itself, not even a response head.
export fn relic_hijack(v: *ExchangeView) void {
    const ex: *Exchange = @fieldParentPtr("view", v);
    ex.hijacked = true;
    ex.done.set();
}

/// Answers with the 101 head Dart encoded, ownership of which passes to
/// native, and makes the connection a WebSocket. The peer's messages come
/// through relic_ws_read and frames go out through relic_ws_send. A
/// message over `max_message` bytes closes the connection with 1009.
export fn relic_ws_upgrade(v: *ExchangeView, head: [*]u8, head_len: u32, max_message: u32) void {
    const ex: *Exchange = @fieldParentPtr("view", v);
    ex.resp_head = head;
    ex.resp_head_len = head_len;
    ex.upgraded = true;
    ex.ws_max_message = max_message;
    ex.done.set();
}

/// Queues a frame for the peer: `opcode` 1 for text, 2 for binary, 9 for
/// a ping, 8 for a close with the code and reason as its payload, after
/// which nothing else goes out. Ownership of `data`, malloc'd by Dart,
/// passes to native. Returns false when the node could not be allocated,
/// in which case `data` still belongs to Dart.
export fn relic_ws_send(v: *ExchangeView, data: ?[*]u8, len: usize, opcode: u8) bool {
    const ex: *Exchange = @fieldParentPtr("view", v);
    const chunk = std.heap.c_allocator.create(Chunk) catch return false;
    chunk.* = .{ .ptr = data, .len = len, .kind = opcode };
    if (opcode == @backingInt(WsOpcode.close)) ex.ws_close_sent = true;
    ex.out.push(&chunk.node);
    ex.out_ready.set();
    return true;
}

/// Takes the next message from the peer. Returns 0 when none is queued.
/// `kind` is a `WsKind`, and `data` is freed with relic_free, or null for
/// an empty payload.
export fn relic_ws_read(v: *ExchangeView, data: *?[*]u8, len: *usize, kind: *u8) u8 {
    const ex: *Exchange = @fieldParentPtr("view", v);
    const node = ex.in.pop() orelse return 0;
    const chunk: *Chunk = @fieldParentPtr("node", node);
    defer std.heap.c_allocator.destroy(chunk);
    data.* = chunk.ptr;
    len.* = chunk.len;
    kind.* = chunk.kind;
    ex.in_pending -= 1;
    ex.credit.set();
    return 1;
}

export fn relic_alloc(len: usize) ?[*]u8 {
    const p = std.c.malloc(len) orelse return null;
    return @ptrCast(p);
}

export fn relic_free(p: [*]u8) void {
    std.c.free(p);
}

export fn relic_server_stats(srv: *Server, out: *Stats) void {
    srv.attach_lock.lock();
    defer srv.attach_lock.unlock();
    var first: u32 = no_slot;
    var active: u32 = 0;
    var idle: u32 = 0;
    for (srv.reactors, 0..) |maybe, i| {
        const r = maybe orelse continue;
        if (first == no_slot) first = @intCast(i);
        active += r.active.load(.monotonic);
        idle += r.idle.load(.monotonic);
    }
    out.* = .{
        .active = active,
        .idle = idle,
        .first_attached = first,
    };
}

test "MPSC queue under contention from several producer threads" {
    var q: Mpsc = undefined;
    q.init();

    const producers = 4;
    const per_producer = 250_000;
    const Ctx = struct {
        fn produce(queue: *Mpsc, nodes: []Node) void {
            for (nodes) |*n| queue.push(n);
        }
    };
    const nodes = try std.testing.allocator.alloc(Node, producers * per_producer);
    defer std.testing.allocator.free(nodes);
    for (nodes) |*n| n.* = .{};

    var threads: [producers]std.Thread = undefined;
    for (&threads, 0..) |*t, i| {
        t.* = try std.Thread.spawn(.{}, Ctx.produce, .{ &q, nodes[i * per_producer .. (i + 1) * per_producer] });
    }
    var popped: usize = 0;
    while (popped < nodes.len) {
        if (q.pop() != null) popped += 1 else std.atomic.spinLoopHint();
    }
    for (&threads) |*t| t.join();
    try std.testing.expect(q.pop() == null);
}

const test_options: Options = .{
    .reactor_capacity = 4,
    .backlog = 16,
    .max_connections = 0,
    .max_inline_body = 1 << 20,
    .idle_timeout_ms = 0,
    .header_timeout_ms = 0,
    .body_timeout_ms = 0,
    .write_timeout_ms = 0,
};

test "registry: the last detach returns without waiting out an accept" {
    const srv = relic_server_bind("poke-group", "127.0.0.1", 0, &test_options) orelse return error.BindFailed;
    const r = relic_reactor_create(srv, 1) orelse return error.CreateFailed;
    const start = zio.Timestamp.now(.monotonic);
    relic_reactor_destroy(r);
    // The accept timeout is a second. A poke ends the wait in a few
    // milliseconds, and well under this even on a loaded machine.
    try std.testing.expect(start.untilNow(.monotonic).toMilliseconds() < 500);
}

test "registry: a group binds once on port 0 and the last detach stops it" {
    const a = relic_server_bind("test-group", "127.0.0.1", 0, &test_options) orelse return error.BindFailed;
    const b = relic_server_bind("test-group", "127.0.0.1", 0, &test_options) orelse return error.BindFailed;
    try std.testing.expect(a == b);
    try std.testing.expect(relic_server_port(a) != 0);

    const ra = relic_reactor_create(a, 1) orelse return error.AttachFailed;
    const rb = relic_reactor_create(b, 2) orelse return error.AttachFailed;
    try std.testing.expect(ra.slot != rb.slot);

    relic_reactor_destroy(ra);
    // Still registered while one reactor is attached.
    try std.testing.expect(relic_server_bind("test-group", "127.0.0.1", 0, &test_options) == a);
    relic_reactor_destroy(rb);
    // Gone, so a new bind creates a new server.
    const c = relic_server_bind("test-group", "127.0.0.1", 0, &test_options) orelse return error.BindFailed;
    try std.testing.expect(c != a or relic_server_port(c) != 0);
    const rc = relic_reactor_create(c, 3) orelse return error.AttachFailed;
    relic_reactor_destroy(rc);
}

test "registry: different groups and no group are separate servers" {
    const a = relic_server_bind("group-a", "127.0.0.1", 0, &test_options) orelse return error.BindFailed;
    const b = relic_server_bind("group-b", "127.0.0.1", 0, &test_options) orelse return error.BindFailed;
    const c = relic_server_bind(null, "127.0.0.1", 0, &test_options) orelse return error.BindFailed;
    try std.testing.expect(a != b and b != c and a != c);
    try std.testing.expect(relic_server_port(a) != relic_server_port(b));
    for ([_]*Server{ a, b, c }) |srv| {
        const r = relic_reactor_create(srv, 1) orelse return error.AttachFailed;
        relic_reactor_destroy(r);
    }
}

test "attach: a full server refuses" {
    const srv = relic_server_bind(null, "127.0.0.1", 0, &test_options) orelse return error.BindFailed;
    var reactors: [4]*Reactor = undefined;
    for (&reactors, 0..) |*r, i| {
        r.* = relic_reactor_create(srv, @intCast(i + 1)) orelse return error.AttachFailed;
    }
    try std.testing.expect(relic_reactor_create(srv, 9) == null);
    for (reactors) |r| relic_reactor_destroy(r);
}

/// The open file descriptors of the process, as fcntl sees them. What a
/// leaked runtime loop or poke pipe shows up in.
fn openFdCount() u32 {
    var n: u32 = 0;
    var fd: c_int = 0;
    while (fd < 4096) : (fd += 1) {
        if (libc.fcntl(fd, std.c.F.GETFD) != -1) n += 1;
    }
    return n;
}

test "accept: a descriptor shortage stalls the acceptor and does not end it" {
    if (builtin.os.tag == .windows) return error.SkipZigTest;
    const srv = relic_server_bind(null, "127.0.0.1", 0, &test_options) orelse return error.BindFailed;
    const r = relic_reactor_create(srv, 1) orelse return error.AttachFailed;
    defer relic_reactor_destroy(r);

    // Every free descriptor below a lowered limit is taken by a filler,
    // one filler then makes way for the client socket, and the accepted
    // connection has nowhere to go.
    const shortages_before = accept_shortages.load(.monotonic);
    const limit = try std.posix.getrlimit(.NOFILE);
    defer std.posix.setrlimit(.NOFILE, limit) catch {};
    try std.posix.setrlimit(.NOFILE, .{ .cur = @intCast(openFdCount() + 8), .max = limit.max });
    var fillers: [64]c_int = undefined;
    var filled: usize = 0;
    while (filled < fillers.len) : (filled += 1) {
        const fd = libc.socket(std.c.AF.INET, std.c.SOCK.STREAM, 0);
        if (fd < 0) break;
        fillers[filled] = fd;
    }
    try std.testing.expect(filled >= 2 and filled < fillers.len);
    defer for (fillers[0..filled]) |fd| {
        _ = libc.close(fd);
    };
    filled -= 1;
    _ = libc.close(fillers[filled]);
    const client = libc.socket(std.c.AF.INET, std.c.SOCK.STREAM, 0);
    try std.testing.expect(client >= 0);
    defer _ = libc.close(client);
    const address: std.c.sockaddr.in = .{
        .port = std.mem.nativeToBig(u16, relic_server_port(srv)),
        .addr = std.mem.nativeToBig(u32, 0x7f000001),
    };
    try std.testing.expectEqual(0, libc.connect(client, @ptrCast(&address), @sizeOf(std.c.sockaddr.in)));
    const request = "GET /x HTTP/1.1\r\nHost: t\r\n\r\n";
    try std.testing.expectEqual(@as(isize, request.len), libc.write(client, request, request.len));

    // The accept fails. How long the shortage lasts is the kernel's
    // business. io_uring allots a descriptor past the limit on the retry.
    var out: [4]*ExchangeView = undefined;
    var rounds: usize = 0;
    while (accept_shortages.load(.monotonic) == shortages_before and rounds < 300) : (rounds += 1) {
        for (out[0..relic_reactor_tick(r, 0, &out, out.len)]) |v| relic_abort(v);
        sleepMs(10);
    }
    try std.testing.expect(accept_shortages.load(.monotonic) > shortages_before);

    // Two descriptors free up and a second client arrives. The acceptor
    // serves it, and the first client too where the kernel kept it.
    filled -= 2;
    _ = libc.close(fillers[filled]);
    _ = libc.close(fillers[filled + 1]);
    const second = libc.socket(std.c.AF.INET, std.c.SOCK.STREAM, 0);
    try std.testing.expect(second >= 0);
    defer _ = libc.close(second);
    try std.testing.expectEqual(0, libc.connect(second, @ptrCast(&address), @sizeOf(std.c.sockaddr.in)));
    const second_request = "GET /y HTTP/1.1\r\nHost: t\r\n\r\n";
    try std.testing.expectEqual(@as(isize, second_request.len), libc.write(second, second_request, second_request.len));
    var served_second = false;
    rounds = 0;
    while (!served_second and rounds < 300) : (rounds += 1) {
        const n = relic_reactor_tick(r, 0, &out, out.len);
        for (out[0..n]) |v| {
            const target = v.head[v.target_off .. v.target_off + v.target_len];
            if (std.mem.eql(u8, target, "/y")) served_second = true else try std.testing.expectEqualStrings("/x", target);
            relic_abort(v);
        }
        sleepMs(10);
    }
    try std.testing.expect(served_second);
}

test "stop: a stopped reactor sheds its idle connections and the last one closes the listener" {
    if (builtin.os.tag == .windows) return error.SkipZigTest;
    const srv = relic_server_bind(null, "127.0.0.1", 0, &test_options) orelse return error.BindFailed;
    const r = relic_reactor_create(srv, 1) orelse return error.AttachFailed;
    defer relic_reactor_destroy(r);
    const address: std.c.sockaddr.in = .{
        .port = std.mem.nativeToBig(u16, relic_server_port(srv)),
        .addr = std.mem.nativeToBig(u32, 0x7f000001),
    };

    const idle = libc.socket(std.c.AF.INET, std.c.SOCK.STREAM, 0);
    try std.testing.expect(idle >= 0);
    defer _ = libc.close(idle);
    try std.testing.expectEqual(0, libc.connect(idle, @ptrCast(&address), @sizeOf(std.c.sockaddr.in)));
    var out: [4]*ExchangeView = undefined;
    var rounds: usize = 0;
    while (r.idle.load(.monotonic) == 0 and rounds < 200) : (rounds += 1) {
        _ = relic_reactor_tick(r, 0, &out, out.len);
        sleepMs(5);
    }
    try std.testing.expectEqual(1, r.connections.load(.monotonic));

    relic_reactor_stop(r);

    rounds = 0;
    while (r.connections.load(.monotonic) != 0 and rounds < 200) : (rounds += 1) {
        _ = relic_reactor_tick(r, 0, &out, out.len);
        sleepMs(5);
    }
    try std.testing.expectEqual(0, r.connections.load(.monotonic));
    // The acceptor closes the listener on its way out, a moment after the stop.
    var refused = false;
    rounds = 0;
    while (!refused and rounds < 200) : (rounds += 1) {
        const probe = libc.socket(std.c.AF.INET, std.c.SOCK.STREAM, 0);
        try std.testing.expect(probe >= 0);
        defer _ = libc.close(probe);
        refused = libc.connect(probe, @ptrCast(&address), @sizeOf(std.c.sockaddr.in)) != 0;
        if (!refused) sleepMs(5);
    }
    try std.testing.expect(refused);
}

test "attach: a refused attach leaks no file descriptors" {
    if (builtin.os.tag == .windows) return error.SkipZigTest;
    const srv = relic_server_bind(null, "127.0.0.1", 0, &test_options) orelse return error.BindFailed;
    var reactors: [4]*Reactor = undefined;
    for (&reactors, 0..) |*r, i| {
        r.* = relic_reactor_create(srv, @intCast(i + 1)) orelse return error.AttachFailed;
    }
    defer for (reactors) |r| relic_reactor_destroy(r);
    const before = openFdCount();

    try std.testing.expect(relic_reactor_create(srv, 9) == null);

    try std.testing.expectEqual(before, openFdCount());
}

test "tick: a request reaches the ready list on the caller's thread and the response goes out" {
    // The client side is libc sockets and poll, which Windows spells
    // differently. The Dart tests cover this path there.
    if (builtin.os.tag == .windows) return error.SkipZigTest;
    const srv = relic_server_bind(null, "127.0.0.1", 0, &test_options) orelse return error.BindFailed;
    const r = relic_reactor_create(srv, 1) orelse return error.AttachFailed;
    defer relic_reactor_destroy(r);

    const client = libc.socket(std.c.AF.INET, std.c.SOCK.STREAM, 0);
    try std.testing.expect(client >= 0);
    const address: std.c.sockaddr.in = .{
        .port = std.mem.nativeToBig(u16, relic_server_port(srv)),
        .addr = std.mem.nativeToBig(u32, 0x7f000001),
    };
    try std.testing.expectEqual(0, libc.connect(client, @ptrCast(&address), @sizeOf(std.c.sockaddr.in)));
    var out: [4]*ExchangeView = undefined;
    // Ticks until the connection task has issued its read, so the bytes
    // arrive through the loop and not through the optimistic first recv.
    var rounds: usize = 0;
    while (rounds < 20) : (rounds += 1) {
        _ = relic_reactor_tick(r, 0, &out, out.len);
        sleepMs(5);
    }
    const request = "GET /x HTTP/1.1\r\nHost: t\r\n\r\n";
    try std.testing.expectEqual(@as(isize, request.len), libc.write(client, request, request.len));

    var n: u32 = 0;
    rounds = 0;
    while (n == 0 and rounds < 200) : (rounds += 1) {
        n = relic_reactor_tick(r, 0, &out, out.len);
        sleepMs(10);
    }
    try std.testing.expectEqual(1, n);
    const v = out[0];
    try std.testing.expectEqualStrings("/x", v.head[v.target_off .. v.target_off + v.target_len]);

    const head = "HTTP/1.1 204 No Content\r\ncontent-length: 0\r\n\r\n";
    const buf = relic_alloc(head.len).?;
    @memcpy(buf[0..head.len], head);
    relic_respond(v, buf, head.len, null, 0, false);
    rounds = 0;
    var got: [64]u8 = undefined;
    var total: usize = 0;
    while (total < head.len and rounds < 200) : (rounds += 1) {
        _ = relic_reactor_tick(r, 10, &out, out.len);
        var pfd = [_]std.posix.pollfd{.{ .fd = client, .events = std.posix.POLL.IN, .revents = 0 }};
        if ((try std.posix.poll(&pfd, 0)) > 0) {
            const got_now = libc.read(client, got[total..].ptr, got.len - total);
            try std.testing.expect(got_now > 0);
            total += @intCast(got_now);
        }
    }
    try std.testing.expectEqualStrings(head, got[0..total]);

    // The peer closes. The connection task reads EOF and ends, which the
    // idle count shows, within a few ticks.
    _ = libc.close(client);
    rounds = 0;
    while (r.idle.load(.monotonic) != 0 and rounds < 100) : (rounds += 1) {
        _ = relic_reactor_tick(r, 0, &out, out.len);
        sleepMs(5);
    }
    try std.testing.expectEqual(0, r.idle.load(.monotonic));
    try std.testing.expectEqual(0, r.connections.load(.monotonic));
}

/// A corpus entry for std.testing.Smith.slice, a little-endian length
/// then the bytes.
fn corpus(comptime request: []const u8) []const u8 {
    return std.mem.toBytes(std.mem.nativeToLittle(u32, request.len)) ++ request;
}

/// One connection's worth of bytes through parseHead, as handleConnInner
/// runs it, with no socket and no Dart. It claims no panic, and that
/// every offset handed to Dart stays inside the head copy.
fn checkRequestBytes(bytes: []const u8) !void {
    var in: std.Io.Reader = .fixed(bytes);
    var sink: std.Io.Writer.Discarding = .init(&.{});
    var http = std.http.Server.init(&in, &sink.writer);
    var head_copy: [max_head]u8 = undefined;
    var slots: [max_headers]HeaderSlot = undefined;
    var tbuf: [1024]u8 = undefined;
    while (true) {
        const head = http.reader.receiveHead() catch return;
        const reference = Head.parse(head);
        const index = parseHead(head, &head_copy, &slots) catch return;
        // Stricter than std.http's parser and never looser, and the same
        // reading of whatever both accept, except Connection. std reads
        // the value as one token, and keeps an HTTP/1.0 connection alive
        // on any token but close.
        var expected = try reference;
        for (slots[0..index.count]) |slot| {
            const colon = std.mem.findScalarPos(u8, head, slot.name_off, ':').?;
            try std.testing.expect(colon < slot.value_off);
            try std.testing.expect(slot.value_off + slot.value_len <= head.len);
            try std.testing.expectEqual(header_names.lookup(head[slot.name_off..colon]), slot.name_id);
            const value = head[slot.value_off..][0..slot.value_len];
            if (slot.name_id == header_names.connection) {
                expected.keep_alive = switch (expected.version) {
                    .@"HTTP/1.1" => !connectionHas(value, "close"),
                    .@"HTTP/1.0" => connectionHas(value, "keep-alive"),
                };
            }
        }
        try std.testing.expectEqualDeep(expected, index.head);
        var req: std.http.Server.Request = .{ .server = &http, .head_buffer = head, .head = index.head };
        try std.testing.expect(index.host_slot < @as(i32, @intCast(index.count)));
        try std.testing.expect(off(head, req.head.target) + req.head.target.len <= head.len);
        if (req.head.transfer_encoding == .chunked or req.head.content_length != null) {
            const br = openBody(&req, &tbuf) catch return;
            _ = br.discardRemaining() catch return;
        }
        if (http.reader.state == .received_head) http.reader.state = .ready;
    }
}

fn fuzzRequestPath(_: void, smith: *std.testing.Smith) !void {
    var input: [2 * max_head]u8 = undefined;
    try checkRequestBytes(input[0..smith.slice(&input)]);
}

const request_corpus = [_][]const u8{
    corpus("GET / HTTP/1.1\r\nHost: x\r\n\r\n"),
    corpus("GET /a?b=c HTTP/1.0\r\nHost: x\r\nConnection: keep-alive\r\n\r\nGET / HTTP/1.0\r\n\r\n"),
    corpus("POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 5\r\n\r\nhelloGET / HTTP/1.1\r\n\r\n"),
    corpus("POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n0\r\n\r\n"),
    corpus("POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n0\r\nX-Trailer: 1\r\n\r\n"),
    corpus("PUT / HTTP/1.1\r\nHost: x\r\nExpect: 100-continue\r\nContent-Length: 2\r\n\r\nok"),
    corpus("DELETE / HTTP/1.1\r\nHost: x\r\nContent-Length: 3\r\n\r\nabc"),
    corpus("GET / HTTP/1.1\r\nA:1\r\nB: 2\r\nC:  3  \r\nD\r\n\r\n"),
    corpus("GET / HTTP/1.1\r\nContent-Length: -1\r\n\r\n"),
    corpus("GET / HTTP/1.1\r\nContent-Length: 99999999999999999999\r\n\r\n"),
    corpus("GET / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\nzz\r\n"),
    corpus("\r\n\r\nGET / HTTP/1.1\r\n\r\n"),
    corpus("GET / HTTP/1.1\n\n"),
    corpus("GET / HTTP/1.1\r\nA : 1\r\nB: a\x00b\r\nC: a\rb\r\nD: a\tb\r\n\r\n"),
};

test "head: a field name is a token and nothing else" {
    try std.testing.expect(isToken("Content-Type"));
    try std.testing.expect(isToken("x_y.z~1"));
    try std.testing.expect(!isToken(""));
    try std.testing.expect(!isToken("X-T "));
    try std.testing.expect(!isToken("X\tT"));
    try std.testing.expect(!isToken("X(T)"));
    try std.testing.expect(!isToken("X\x80"));
}

test "head: a field value refuses control characters but a tab" {
    try std.testing.expect(!hasControl(""));
    try std.testing.expect(!hasControl(" a\tb caf\xe9 "));
    try std.testing.expect(hasControl("a\x00b"));
    try std.testing.expect(hasControl("a\rb"));
    try std.testing.expect(hasControl("a\x7fb"));
    // Past the first vector chunk, in the chunk and in the tail.
    try std.testing.expect(!hasControl("0123456789abcdef0123456789abcdef\tend"));
    try std.testing.expect(hasControl("0123456789abcdef01234567\x0189abcdef"));
    try std.testing.expect(hasControl("0123456789abcdef0123456789abcdef\x1f"));
}

test "head: Content-Length is decimal digits and nothing else" {
    try std.testing.expectEqual(@as(?u64, 0), parseContentLength("0"));
    try std.testing.expectEqual(@as(?u64, 1234567890), parseContentLength("1234567890"));
    try std.testing.expectEqual(@as(?u64, std.math.maxInt(u64)), parseContentLength("18446744073709551615"));
    try std.testing.expectEqual(@as(?u64, null), parseContentLength(""));
    try std.testing.expectEqual(@as(?u64, null), parseContentLength("+10"));
    try std.testing.expectEqual(@as(?u64, null), parseContentLength("-1"));
    try std.testing.expectEqual(@as(?u64, null), parseContentLength("1_0"));
    try std.testing.expectEqual(@as(?u64, null), parseContentLength("10 "));
    try std.testing.expectEqual(@as(?u64, null), parseContentLength("0x10"));
    try std.testing.expectEqual(@as(?u64, null), parseContentLength("18446744073709551616"));
}

test "head: a request target is visible ASCII and nothing else" {
    try std.testing.expect(isTarget("/"));
    try std.testing.expect(isTarget("/a/b?c=d%20e#"));
    try std.testing.expect(isTarget("http://h:80/p"));
    try std.testing.expect(isTarget("*"));
    try std.testing.expect(!isTarget(""));
    try std.testing.expect(!isTarget("/a b"));
    try std.testing.expect(!isTarget("/a\tb"));
    try std.testing.expect(!isTarget("/a\x00b"));
    try std.testing.expect(!isTarget("/a\x7f"));
    try std.testing.expect(!isTarget("/caf\xc3\xa9"));
    // Past the first vector chunk, in the chunk and in the tail.
    try std.testing.expect(isTarget("/0123456789abcdef0123456789abcdef/end"));
    try std.testing.expect(!isTarget("/0123456789abcdef0123456 89abcdef"));
    try std.testing.expect(!isTarget("/0123456789abcdef0123456789abcdef\x80"));
}

test "head: HTTP/1.1 needs one Host and HTTP/1.0 may have none" {
    var head_copy: [max_head]u8 = undefined;
    var slots: [max_headers]HeaderSlot = undefined;
    const one = try parseHead("GET / HTTP/1.1\r\nHost: a\r\n\r\n", &head_copy, &slots);
    try std.testing.expectEqual(@as(i32, 0), one.host_slot);
    const none10 = try parseHead("GET / HTTP/1.0\r\n\r\n", &head_copy, &slots);
    try std.testing.expectEqual(@as(i32, -1), none10.host_slot);
    try std.testing.expectError(error.MalformedHead, parseHead("GET / HTTP/1.1\r\n\r\n", &head_copy, &slots));
    try std.testing.expectError(error.MalformedHead, parseHead("GET / HTTP/1.1\r\nHost: a\r\nHost: b\r\n\r\n", &head_copy, &slots));
    try std.testing.expectError(error.MalformedHead, parseHead("GET / HTTP/1.0\r\nHost: a\r\nhost: a\r\n\r\n", &head_copy, &slots));
}

test "head: the Connection tokens decide keep-alive by version" {
    var head_copy: [max_head]u8 = undefined;
    var slots: [max_headers]HeaderSlot = undefined;
    const list = try parseHead("GET / HTTP/1.1\r\nHost: x\r\nConnection: TE, close\r\n\r\n", &head_copy, &slots);
    try std.testing.expect(!list.head.keep_alive);
    const first = try parseHead("GET / HTTP/1.1\r\nHost: x\r\nConnection: Close ,TE\r\n\r\n", &head_copy, &slots);
    try std.testing.expect(!first.head.keep_alive);
    const other = try parseHead("GET / HTTP/1.1\r\nHost: x\r\nConnection: TE, closer\r\n\r\n", &head_copy, &slots);
    try std.testing.expect(other.head.keep_alive);
    const alive = try parseHead("GET / HTTP/1.0\r\nConnection: keep-alive\r\n\r\n", &head_copy, &slots);
    try std.testing.expect(alive.head.keep_alive);
    const listed = try parseHead("GET / HTTP/1.0\r\nConnection: TE, Keep-Alive\r\n\r\n", &head_copy, &slots);
    try std.testing.expect(listed.head.keep_alive);
    const te = try parseHead("GET / HTTP/1.0\r\nConnection: TE\r\n\r\n", &head_copy, &slots);
    try std.testing.expect(!te.head.keep_alive);
    const none = try parseHead("GET / HTTP/1.0\r\n\r\n", &head_copy, &slots);
    try std.testing.expect(!none.head.keep_alive);
}

test "head: Transfer-Encoding beside Content-Length is refused" {
    var head_copy: [max_head]u8 = undefined;
    var slots: [max_headers]HeaderSlot = undefined;
    const chunked = try parseHead("POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\n", &head_copy, &slots);
    try std.testing.expectEqual(.chunked, chunked.head.transfer_encoding);
    try std.testing.expectError(error.MalformedHead, parseHead("POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\nContent-Length: 5\r\n\r\n", &head_copy, &slots));
    try std.testing.expectError(error.MalformedHead, parseHead("POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 5\r\nTransfer-Encoding: chunked\r\n\r\n", &head_copy, &slots));
    try std.testing.expectError(error.MalformedHead, parseHead("POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 5\r\nTransfer-Encoding: gzip\r\n\r\n", &head_copy, &slots));
}

test "fuzz: the request parse path panics on nothing and indexes within the head" {
    try std.testing.fuzz({}, fuzzRequestPath, .{ .corpus = &request_corpus });
}

/// Pieces a mutation splices in, so the sweep reaches past the byte
/// flips into the framing and the field grammar.
const request_tokens = [_][]const u8{
    "\r\n",                "\n",      " ",                    "\t",             ":",
    "0",                   "9",       "-",                    "\r\n\r\n",       "Content-Length: ",
    "Transfer-Encoding: ", "chunked", "Expect: 100-continue", "HTTP/1.1",       "HTTP/1.0",
    "GET ",                "POST ",   "0\r\n\r\n",            "5\r\nhello\r\n", "ffffffffffffffff\r\n",
};

// Zig 0.17.0 does not link the tests in fuzz mode on macOS, so the suite
// carries its own sweep, seeded mutations of the corpus with no coverage
// guidance. `zig build test --fuzz` takes over once the toolchain builds.
test "fuzz: a seeded mutation sweep over the request corpus" {
    var prng = std.Random.DefaultPrng.init(0x7e11c);
    const random = prng.random();
    var buf: [2 * max_head]u8 = undefined;
    var round: usize = 0;
    while (round < 20_000) : (round += 1) {
        const seed = request_corpus[random.uintLessThan(usize, request_corpus.len)][4..];
        var len = seed.len;
        @memcpy(buf[0..len], seed);
        const mutations = 1 + random.uintLessThan(usize, 8);
        var m: usize = 0;
        while (m < mutations) : (m += 1) {
            switch (random.uintLessThan(u8, 4)) {
                0 => if (len > 0) {
                    buf[random.uintLessThan(usize, len)] = random.int(u8);
                },
                1 => if (len > 0) {
                    const at = random.uintLessThan(usize, len);
                    std.mem.copyForwards(u8, buf[at .. len - 1], buf[at + 1 .. len]);
                    len -= 1;
                },
                2 => {
                    const token = request_tokens[random.uintLessThan(usize, request_tokens.len)];
                    if (len + token.len > buf.len) continue;
                    const at = random.uintAtMost(usize, len);
                    std.mem.copyBackwards(u8, buf[at + token.len .. len + token.len], buf[at..len]);
                    @memcpy(buf[at .. at + token.len], token);
                    len += token.len;
                },
                else => if (len > 0) {
                    const at = random.uintLessThan(usize, len);
                    const span = @min(random.uintLessThan(usize, 64) + 1, len - at);
                    if (len + span > buf.len) continue;
                    std.mem.copyBackwards(u8, buf[at + span .. len + span], buf[at..len]);
                    len += span;
                },
            }
        }
        try checkRequestBytes(buf[0..len]);
    }
}

test "ws: a frame head is read as a server reads a client's" {
    var in: std.Io.Reader = .fixed(&.{ 0x81, 0x83, 1, 2, 3, 4, 'a', 'b', 'c' });
    const head = (try readFrameHead(&in, false, 1 << 20)).head;
    try std.testing.expect(head.fin);
    try std.testing.expectEqual(WsOpcode.text, head.opcode);
    try std.testing.expectEqual(@as(u64, 3), head.len);
    try std.testing.expectEqual([4]u8{ 1, 2, 3, 4 }, head.mask);
    // The payload is left for the caller.
    try std.testing.expectEqual(@as(usize, 3), in.bufferedLen());

    var two: std.Io.Reader = .fixed(&.{ 0x82, 0xfe, 0x01, 0x00, 0, 0, 0, 0 });
    try std.testing.expectEqual(@as(u64, 256), (try readFrameHead(&two, false, 1 << 20)).head.len);
    var eight: std.Io.Reader = .fixed(&.{ 0x82, 0xff, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0 });
    try std.testing.expectEqual(@as(u64, 1 << 16), (try readFrameHead(&eight, false, 1 << 20)).head.len);

    // What may continue a message, and what may interrupt one.
    var cont: std.Io.Reader = .fixed(&.{ 0x80, 0x80, 0, 0, 0, 0 });
    try std.testing.expectEqual(WsOpcode.continuation, (try readFrameHead(&cont, true, 1 << 20)).head.opcode);
    var ping: std.Io.Reader = .fixed(&.{ 0x89, 0x80, 0, 0, 0, 0 });
    try std.testing.expectEqual(WsOpcode.ping, (try readFrameHead(&ping, true, 1 << 20)).head.opcode);
}

test "ws: a frame the peer may not send is refused with its close code" {
    const Case = struct { bytes: []const u8, in_message: bool = false, max: u64 = 1 << 20, code: u16 };
    const cases = [_]Case{
        .{ .bytes = &.{ 0x81, 0x01, 'a' }, .code = 1002 }, // unmasked
        .{ .bytes = &.{ 0xc1, 0x80, 0, 0, 0, 0 }, .code = 1002 }, // RSV1
        .{ .bytes = &.{ 0x83, 0x80, 0, 0, 0, 0 }, .code = 1002 }, // opcode 3
        .{ .bytes = &.{ 0x09, 0x80, 0, 0, 0, 0 }, .code = 1002 }, // a fragmented ping
        .{ .bytes = &.{ 0x89, 0xfe, 0, 126, 0, 0, 0, 0 }, .code = 1002 }, // a ping of 126 bytes
        .{ .bytes = &.{ 0x80, 0x80, 0, 0, 0, 0 }, .code = 1002 }, // a continuation outside a message
        .{ .bytes = &.{ 0x81, 0x80, 0, 0, 0, 0 }, .in_message = true, .code = 1002 }, // text inside one
        .{ .bytes = &.{ 0x82, 0xff, 0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, .code = 1002 }, // a 64-bit length with its top bit
        .{ .bytes = &.{ 0x82, 0xfe, 0x10, 0x00, 0, 0, 0, 0 }, .max = 4095, .code = 1009 }, // 4096 over a limit of 4095
    };
    for (cases) |case| {
        var in: std.Io.Reader = .fixed(case.bytes);
        const result = try readFrameHead(&in, case.in_message, case.max);
        try std.testing.expectEqual(case.code, result.violation.code);
    }
}

test "ws: unmask reaches past the vector blocks into the tail" {
    var data: [37]u8 = undefined;
    for (&data, 0..) |*b, i| b.* = @intCast(i);
    const mask = [4]u8{ 0xa5, 0x5a, 0x0f, 0xf0 };
    unmask(&data, mask);
    for (data, 0..) |b, i| try std.testing.expectEqual(@as(u8, @intCast(i)) ^ mask[i & 3], b);
}

test "ws: a server frame reads back through the client parser" {
    const sizes = [_]usize{ 0, 125, 126, 65535, 65536 };
    for (sizes) |size| {
        const payload = try std.testing.allocator.alloc(u8, size);
        defer std.testing.allocator.free(payload);
        @memset(payload, 'x');
        const buf = try std.testing.allocator.alloc(u8, size + 10);
        defer std.testing.allocator.free(buf);
        var out: std.Io.Writer = .fixed(buf);
        try writeFrame(&out, .binary, payload);
        const written = out.buffered();
        const head_len = written.len - size;
        try std.testing.expectEqual(@as(usize, if (size < 126) 2 else if (size <= 0xffff) 4 else 10), head_len);

        // A client's copy of it: the mask bit set and a zero mask, which
        // changes no payload byte.
        const masked = try std.testing.allocator.alloc(u8, written.len + 4);
        defer std.testing.allocator.free(masked);
        @memcpy(masked[0..head_len], written[0..head_len]);
        masked[1] |= 0x80;
        @memset(masked[head_len .. head_len + 4], 0);
        @memcpy(masked[head_len + 4 ..], written[head_len..]);
        var in: std.Io.Reader = .fixed(masked);
        const head = (try readFrameHead(&in, false, 1 << 20)).head;
        try std.testing.expectEqual(WsOpcode.binary, head.opcode);
        try std.testing.expectEqual(@as(u64, size), head.len);
        try std.testing.expectEqual(size, in.bufferedLen());
    }
}

test "ws: the close codes a peer may send" {
    for ([_]u16{ 1000, 1001, 1003, 1007, 1011, 1014, 3000, 4999 }) |code| try std.testing.expect(isValidCloseCode(code));
    for ([_]u16{ 0, 999, 1004, 1005, 1006, 1015, 1016, 2999, 5000 }) |code| try std.testing.expect(!isValidCloseCode(code));
}
