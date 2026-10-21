//! The http_load.dart routes on dusty, a Zig HTTP server on zio, as the
//! floor for relic_native, which runs on the same zio. One executor, so it
//! compares with one isolate.
//!
//!   zig build run --release -- 8093
//!   dart run bin/http_load.dart --targets=dusty=http://127.0.0.1:8093
const std = @import("std");
const zio = @import("zio");
const http = @import("dusty");

pub const std_options_debug_io = zio.debug_io;

const etag = "\"relic-browser-1\"";

/// The JSON array the browser route sends, built once at startup.
var items: []const u8 = "";

fn buildItems(gpa: std.mem.Allocator) ![]const u8 {
    var out: std.Io.Writer.Allocating = .init(gpa);
    const w = &out.writer;
    try w.writeByte('[');
    for (0..20) |i| {
        if (i > 0) try w.writeByte(',');
        try w.print("{{\"id\":{d},\"name\":\"item {d}\",\"tags\":[\"new\",\"sale\"],\"price\":{d}}}", .{ i, i, 100 + i });
    }
    try w.writeByte(']');
    return out.toOwnedSlice();
}

fn writeJsonString(w: *std.Io.Writer, value: ?[]const u8) !void {
    const s = value orelse return w.writeAll("null");
    try w.writeByte('"');
    for (s) |c| switch (c) {
        '"' => try w.writeAll("\\\""),
        '\\' => try w.writeAll("\\\\"),
        0...0x1f => try w.print("\\u{x:0>4}", .{c}),
        else => try w.writeByte(c),
    };
    try w.writeByte('"');
}

fn plaintext(_: *http.Request, res: *http.Response) !void {
    res.content_type = .text;
    res.body = "Hello, World!";
}

fn headers(req: *http.Request, res: *http.Response) !void {
    const agent = req.headers.get("user-agent") orelse "";
    const languages = if (req.headers.get("accept-language")) |v| std.mem.countScalar(u8, v, ',') + 1 else 0;
    const session = req.cookies().get("session");
    res.content_type = .text;
    res.body = try std.fmt.allocPrint(req.arena, "{d} {d} {d}", .{
        agent.len,
        languages,
        if (session) |s| s.len else 0,
    });
}

fn browser(req: *http.Request, res: *http.Response) !void {
    try res.header("etag", etag);
    if (req.headers.get("if-none-match")) |tag| {
        if (std.mem.eql(u8, tag, etag)) {
            res.status = .not_modified;
            return;
        }
    }
    try res.header("cache-control", "private, max-age=60");
    res.content_type = .json;
    var body: std.Io.Writer.Allocating = .init(req.arena);
    const w = &body.writer;
    try w.writeAll("{\"host\":");
    try writeJsonString(w, req.headers.get("host"));
    try w.writeAll(",\"session\":");
    try writeJsonString(w, req.cookies().get("session"));
    try w.writeAll(",\"items\":");
    try w.writeAll(items);
    try w.writeByte('}');
    res.body = body.written();
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const port = if (args.len > 1) try std.fmt.parseInt(u16, args[1], 10) else 8093;
    items = try buildItems(init.arena.allocator());

    const rt = try zio.Runtime.init(init.gpa, .{ .executors = .exact(1) });
    defer rt.deinit();

    const address: http.Address = .{ .ip = .{ .ip4 = .loopback(port) } };
    var server = http.Server(void).init(init.gpa, rt.io(), .{ .listeners = &.{.{ .address = address }} }, {});
    defer server.deinit();
    server.router.get("/plaintext", plaintext);
    server.router.get("/headers", headers);
    server.router.get("/browser", browser);

    std.debug.print("listening on http://127.0.0.1:{d}/\n", .{port});
    try server.run();
}
