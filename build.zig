const std = @import("std");
const buildtools = @import("zevy_buildtools");
const jok = @import("jok");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const zevy_ecs_dep = b.dependency("zevy_ecs", .{
        .optimize = optimize,
        .target = target,
    });
    const zevy_ecs = zevy_ecs_dep.module("zevy_ecs");
    const benchmark = zevy_ecs_dep.module("benchmark");
    const plugins = zevy_ecs_dep.module("plugins");

    const jok_dep = jok.getJokLibrary(b, target, optimize, .{});
    const sdl = jok.sdlModule(b, target, optimize, .{});

    const mod = b.addModule("zevy_jok", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zevy_ecs", .module = zevy_ecs },
            .{ .name = "plugins", .module = plugins },
            .{ .name = "benchmark", .module = benchmark },
            .{ .name = "jok", .module = jok_dep.module },
            .{ .name = "sdl", .module = sdl },
        },
    });

    const exe = jok.createDesktopApp(b, "zevy_jok", "src/main.zig", target, optimize, .{
        .additional_deps = &.{
            .{ .name = "zevy_jok", .mod = mod },
            .{ .name = "zevy_ecs", .mod = zevy_ecs },
            .{ .name = "plugins", .mod = plugins },
            .{ .name = "benchmark", .mod = benchmark },
            .{ .name = "jok", .mod = jok_dep.module },
            .{ .name = "sdl", .mod = sdl },
        },
    });

    b.installArtifact(jok_dep.artifact);

    // This declares intent for the executable to be installed into the
    // install prefix when running `zig build` (i.e. when executing the default
    // step). By default the install prefix is `zig-out/` but can be overridden
    // by passing `--prefix` or `-p`.
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    // This creates a RunArtifact step in the build graph. A RunArtifact step
    // invokes an executable compiled by Zig. Steps will only be executed by the
    // runner if invoked directly by the user (in the case of top level steps)
    // or if another step depends on it, so it's up to you to define when and
    // how this Run step will be executed. In our case we want to run it when
    // the user runs `zig build run`, so we create a dependency link.
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    // By making the run step depend on the default step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Creates an executable that will run `test` blocks from the provided module.
    // Here `mod` needs to define a target, which is why earlier we made sure to
    // set the releative field.
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    // A run step that will run the test executable.
    const run_mod_tests = b.addRunArtifact(mod_tests);

    // Creates an executable that will run `test` blocks from the executable's
    // root module. Note that test executables only test one module at a time,
    // hence why we have to create two separate ones.
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    // A run step that will run the second test executable.
    const run_exe_tests = b.addRunArtifact(exe_tests);

    // A top level step for running all tests. dependOn can be called multiple
    // times and since the two run steps do not depend on one another, this will
    // make the two of them run in parallel.
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    try buildtools.deps.addDepsStep(b);
    try buildtools.fetch.addFetchStep(b, b.path("build.zig.zon"));
    buildtools.fetch.addGetStep(b);
    try buildtools.fmt.addFmtStep(b, true);
}
