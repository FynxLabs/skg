const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("skg", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_tests = b.addRunArtifact(tests);

    const malformed_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/malformed_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_malformed_tests = b.addRunArtifact(malformed_tests);

    const test_step = b.step("test", "Run SKG parser tests");
    test_step.dependOn(&run_tests.step);
    test_step.dependOn(&run_malformed_tests.step);
}
