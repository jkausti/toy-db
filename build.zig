const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "dbstar",
        .root_source_file = b.path("cli/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const utils = b.createModule(.{
        .root_source_file = b.path("utils/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    const storage = b.createModule(.{
        .root_source_file = b.path("storage/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    utils.addImport("storage", storage);
    storage.addImport("utils", utils);

    exe.root_module.addImport("storage", storage);
    exe.root_module.addImport("utils", utils);

    b.installArtifact(exe);

    // tests setup

    // const st_engine_tests = b.addTest(.{
    //     .root_module = storage,
    // });
    //
    // const run_st_engine_test = b.addRunArtifact(st_engine_tests);
    //
    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_st_engine_test.step);
}
