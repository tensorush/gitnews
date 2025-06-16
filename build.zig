const std = @import("std");

pub fn build(b: *std.Build) void {
    const install_step = b.getInstallStep();
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const root_source_file = b.path("src/main.zig");
    const version = std.SemanticVersion{ .major = 1, .minor = 2, .patch = 0 };

    // Executable
    const exe_run_step = b.step("run", "Run executable");

    const exe = b.addExecutable(.{
        .name = "gitnews",
        .version = version,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = root_source_file,
        }),
    });
    b.installArtifact(exe);

    const exe_run = b.addRunArtifact(exe);
    exe_run_step.dependOn(&exe_run.step);

    // Formatting check
    const fmt_step = b.step("fmt", "Check formatting");

    const fmt = b.addFmt(.{
        .paths = &.{
            "src/",
            "build.zig",
            "build.zig.zon",
        },
        .check = true,
    });
    fmt_step.dependOn(&fmt.step);
    install_step.dependOn(fmt_step);
}
