const std = @import("std");

pub fn build(b: *std.Build) void {
    // Githunt Hacker News GitHub links reporter
    const githunt_step = b.step("githunt", "Run Githunt Hacker News GitHub links reporter");

    const githunt = b.addExecutable(.{
        .name = "githunt",
        .root_source_file = std.Build.FileSource.relative("src/main.zig"),
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
        .version = .{ .major = 0, .minor = 1, .patch = 0 },
    });

    const githunt_run = b.addRunArtifact(githunt);

    githunt_step.dependOn(&githunt_run.step);
    b.default_step.dependOn(githunt_step);

    // Lints
    const lints_step = b.step("lint", "Run lints");

    const lints = b.addFmt(.{
        .paths = &.{ "src", "build.zig" },
        .check = true,
    });

    lints_step.dependOn(&lints.step);
    b.default_step.dependOn(lints_step);
}
