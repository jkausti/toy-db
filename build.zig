const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const storage = b.createModule(.{
        .root_source_file = b.path("storage/lib.zig"),
    });

    const exe = b.addExecutable(.{
        .name = "dbstar",
        .root_source_file = b.path("cli/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("storage", storage);

    b.installArtifact(exe);
}
