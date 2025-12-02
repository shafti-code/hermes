const std = @import("std");

pub fn build(b: *std.Build) void {

    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});


    const exe = b.addExecutable(.{
        .name = "zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            // .imports = &.{
            //     .{ .name = "zig"},
            // },
        }),
    });

    exe.linkSystemLibrary("enet");

    b.installArtifact(exe);
    
    const tests = b.addExecutable(.{
        .name = "test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/testing.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    tests.linkSystemLibrary("enet");
    const run_step = b.step("run", "Run the app");
    const test_step = b.step("test","Run the test client");

    const run_cmd = b.addRunArtifact(exe);
    const test_cmd = b.addRunArtifact(tests);
    run_step.dependOn(&run_cmd.step);
    test_step.dependOn(&test_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
