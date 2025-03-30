const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "dbstar",
        .root_source_file = b.path("cli/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const storage = b.createModule(.{
        .root_source_file = b.path("storage/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("storage", storage);

    b.installArtifact(exe);

    // tests setup

    const test_exe = b.addTest(.{
        .root_source_file = b.path("tests/lib.zig"),
        .filters = b.option(
            []const []const u8,
            "test-filter",
            "test-filter",
        ) orelse &.{},
        .test_runner = .{ .path = b.path("test_runner.zig"), .mode = .simple },
    });
    test_exe.root_module.addImport("storage", storage);
    const run_test = b.addRunArtifact(test_exe);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_test.step);
}
