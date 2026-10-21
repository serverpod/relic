const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseFast,
    });
    const zio = b.dependency("zio", .{ .target = target, .optimize = optimize });
    const dusty = b.dependency("dusty", .{
        .target = target,
        .optimize = optimize,
        .use_zlib = false,
    });
    // dusty's deadlines cancel the connection task on zio, and fall back to
    // a watchdog task per connection without it.
    const dusty_module = dusty.module("dusty");
    dusty_module.addImport("zio", zio.module("zio"));

    const exe = b.addExecutable(.{
        .name = "relic_baseline_dusty",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "dusty", .module = dusty_module },
                .{ .name = "zio", .module = zio.module("zio") },
            },
        }),
    });
    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    run.addPassthruArgs();
    b.step("run", "Run the server").dependOn(&run.step);
}
