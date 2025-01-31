const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const root_source_file = b.path("src/main.zig");
    const version = std.SemanticVersion{ .major = 1, .minor = 1, .patch = 1 };

    // Executable
    const exe_step = b.step("exe", "Run executable");

    const exe = b.addExecutable(.{
        .name = "githunt",
        .target = target,
        .version = version,
        .optimize = optimize,
        .root_source_file = root_source_file,
    });
    b.installArtifact(exe);

    const exe_run = b.addRunArtifact(exe);
    exe_step.dependOn(&exe_run.step);
    b.default_step.dependOn(exe_step);

    // Formatting checks
    const fmt_step = b.step("fmt", "Run formatting checks");

    const fmt = b.addFmt(.{
        .paths = &.{
            "src/",
            "build.zig",
        },
        .check = true,
    });
    fmt_step.dependOn(&fmt.step);
    b.default_step.dependOn(fmt_step);
}
