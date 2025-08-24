const std = @import("std");

const manifest = @import("build.zig.zon");

pub fn build(b: *std.Build) !void {
    const install_step = b.getInstallStep();
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const root_source_file = b.path("src/main.zig");
    const version: std.SemanticVersion = try .parse(manifest.version);

    // Private root module
    const root_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = root_source_file,
        .strip = b.option(bool, "strip", "Strip the binary"),
    });

    // Executable
    const exe_run_step = b.step("run", "Run executable");

    const exe = b.addExecutable(.{
        .name = "gitnews",
        .version = version,
        .root_module = root_mod,
    });
    b.installArtifact(exe);

    const exe_run = b.addRunArtifact(exe);
    if (b.args) |args| {
        exe_run.addArgs(args);
    }
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

    // Compilation check for ZLS Build-On-Save
    // See: https://zigtools.org/zls/guides/build-on-save/
    const check_step = b.step("check", "Check compilation");
    const check_exe = b.addExecutable(.{
        .name = "gitnews",
        .version = version,
        .root_module = root_mod,
    });
    check_step.dependOn(&check_exe.step);
}
