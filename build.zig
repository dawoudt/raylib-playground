const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "raylib-playground",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const obstacle_mod = b.addModule("Obstacle", .{
        .root_source_file = b.path("lib/Obstacle.zig"),
    });
    exe.root_module.addImport("Obstacle", obstacle_mod);

    const utils_mod = b.addModule("utils", .{
        .root_source_file = b.path("lib/utils.zig"),
    });

    exe.root_module.addImport("utils", utils_mod);
    utils_mod.addImport("Obstacle", obstacle_mod);

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    exe.linkFramework("Cocoa");
    exe.linkLibrary(raylib_artifact);

    for ([_]*std.Build.Module{
        exe.root_module,
        obstacle_mod,
        utils_mod,
    }) |m| {
        m.addImport("raylib", raylib);
        m.addImport("raygui", raygui);
    }

    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);
}
