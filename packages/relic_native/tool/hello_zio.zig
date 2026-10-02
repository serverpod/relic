// A hello server on zio alone, with no Dart in the process. It keeps
// relic_native's syscall pattern, a timed read and a timed write per
// request on one executor, and is the baseline for what the adapter costs
// on top of zio.
//
//   zig build baseline --release=fast && ./zig-out/bin/hello_zio
//   dart run bin/cpu_bench.dart -- ../relic_native/zig-out/bin/hello_zio
const std = @import("std");
const zio = @import("zio");

const response = "HTTP/1.1 200 OK\r\ncontent-type: text/plain; charset=utf-8\r\ndate: Thu, 01 Oct 2026 18:00:00 GMT\r\ncontent-length: 5\r\n\r\nHello";

fn handleClient(stream: zio.net.Stream) void {
    defer stream.close();
    var buf: [8192]u8 = undefined;
    var len: usize = 0;
    while (true) {
        const n = stream.read(buf[len..], .fromMilliseconds(30000)) catch return;
        if (n == 0) return;
        len += n;
        while (std.mem.indexOf(u8, buf[0..len], "\r\n\r\n")) |end| {
            stream.writeAll(response, .fromMilliseconds(30000)) catch return;
            const consumed = end + 4;
            std.mem.copyForwards(u8, buf[0..], buf[consumed..len]);
            len -= consumed;
        }
        if (len == buf.len) return;
    }
}

pub fn main() !void {
    const rt = try zio.Runtime.init(std.heap.smp_allocator, .{ .executors = .exact(1) });
    defer rt.deinit();
    const addr = try zio.net.IpAddress.parseIp4("127.0.0.1", 18099);
    const server = try addr.listen(.{ .reuse_address = true, .kernel_backlog = 128 });
    defer server.close();
    var group: zio.Group = .init;
    defer group.cancel();
    while (true) {
        const stream = try server.accept(.{});
        errdefer stream.close();
        try group.spawn(handleClient, .{stream});
    }
}
