// Builds librelic_native for one target per invocation:
//
//   zig build -Dtarget=aarch64-macos --release=fast
//
// hook/build.dart and tool/build_binaries.dart drive this for every
// supported target. The library links libc. The Dart DL API is C, and zio
// uses the C allocator for what Dart frees.
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseFast,
    });
    const strip = b.option(bool, "strip", "Strip debug info (used for published binaries)") orelse false;
    const sanitize_thread = b.option(bool, "sanitize-thread", "Build the unit tests under ThreadSanitizer") orelse false;

    // zio makes an io_uring ring SINGLE_ISSUER unless told not to, and
    // only the thread that made such a ring may enter it. The Dart VM
    // moves an isolate between the threads of its pool, so the ring goes
    // without it.
    const zio = b.dependency("zio", .{
        .target = target,
        .optimize = optimize,
        .io_uring_single_issuer = false,
    });

    // The Dart DL API header, translated once and imported as a module by
    // the library and the tests. @cImport is gone from the language as of
    // 0.17, and this is its replacement.
    const dart_dl = b.addTranslateC(.{
        .root_source_file = b.path("src/dart-dl/dart_api_dl.h"),
        .target = target,
        .optimize = optimize,
    });
    dart_dl.addIncludePath(b.path("src/dart-dl"));
    const dart_dl_module = dart_dl.createModule();

    const module = b.createModule(.{
        .root_source_file = b.path("src/relic_native.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
        .link_libc = true,
    });
    module.addImport("zio", zio.module("zio"));
    module.addImport("dart_dl", dart_dl_module);
    module.addIncludePath(b.path("src/dart-dl"));
    module.addCSourceFile(.{ .file = b.path("src/dart-dl/dart_api_dl.c"), .flags = &.{} });

    const lib = b.addLibrary(.{
        .name = "relic_native",
        .linkage = .dynamic,
        .root_module = module,
    });
    if (target.result.os.tag.isDarwin()) {
        // Leaves room for install_name_tool, which the Dart native asset
        // tooling runs on Apple dylibs.
        lib.headerpad_max_install_names = true;
    }
    b.installArtifact(lib);

    // The tests get their own module so the sanitizer never reaches the
    // library Dart loads. A sanitizer runtime must be in the process from
    // the start, which a dlopen into the Dart VM is not.
    const test_module = b.createModule(.{
        .root_source_file = b.path("src/relic_native.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .sanitize_thread = sanitize_thread,
    });
    test_module.addImport("zio", zio.module("zio"));
    test_module.addImport("dart_dl", dart_dl_module);
    test_module.addIncludePath(b.path("src/dart-dl"));
    test_module.addCSourceFile(.{ .file = b.path("src/dart-dl/dart_api_dl.c"), .flags = &.{} });
    const tests = b.addTest(.{ .root_module = test_module });
    b.step("test", "Run the native unit tests").dependOn(&b.addRunArtifact(tests).step);

    // The hello route on zio alone, the baseline the adapter's cost is
    // measured against. Not part of the default build.
    const baseline = b.addExecutable(.{
        .name = "hello_zio",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tool/hello_zio.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{.{ .name = "zio", .module = zio.module("zio") }},
        }),
    });
    b.step("baseline", "Build the zio-only hello server").dependOn(&b.addInstallArtifact(baseline, .{}).step);
}
