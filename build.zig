const std = @import("std");
const buildtools = @import("zevy_buildtools");
const jok = @import("jok");

const CommonDeps = struct {
    zevy_mem: *std.Build.Module,
    zevy_jok: *std.Build.Module,
    zevy_ecs: *std.Build.Module,
    plugins: *std.Build.Module,
    jok: *std.Build.Module,
    sdl: *std.Build.Module,
};

const AppOptions = struct {
    additional_deps: []const jok.Dependency = &.{},
};

fn createApp(
    b: *std.Build,
    name: []const u8,
    root_source_file: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    common_deps: CommonDeps,
    options: AppOptions,
) !*std.Build.Step.Compile {
    const deps = try b.allocator.alloc(jok.Dependency, 6 + options.additional_deps.len);
    deps[0] = .{ .name = "zevy_mem", .mod = common_deps.zevy_mem };
    deps[1] = .{ .name = "zevy_jok", .mod = common_deps.zevy_jok };
    deps[2] = .{ .name = "zevy_ecs", .mod = common_deps.zevy_ecs };
    deps[3] = .{ .name = "plugins", .mod = common_deps.plugins };
    deps[4] = .{ .name = "jok", .mod = common_deps.jok };
    deps[5] = .{ .name = "sdl", .mod = common_deps.sdl };
    std.mem.copyForwards(jok.Dependency, deps[6..], options.additional_deps);

    return jok.createDesktopApp(b, name, root_source_file, target, optimize, .{
        .additional_deps = deps,
    });
}

fn addExampleSteps(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    common_deps: CommonDeps,
) !void {
    var threaded = std.Io.Threaded.init_single_threaded;
    const io = threaded.io();
    var examples_dir = try std.Io.Dir.cwd().openDir(io, "examples", .{ .iterate = true });
    defer examples_dir.close(io);

    var iter = examples_dir.iterate();
    while (try iter.next(io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".zig")) continue;

        const stem = std.fs.path.stem(entry.name);
        const step_name = try std.fmt.allocPrint(b.allocator, "example-{s}", .{stem});
        const step_desc = try std.fmt.allocPrint(b.allocator, "Run the {s} example", .{stem});
        const exe_name = try std.fmt.allocPrint(b.allocator, "zevy_jok_example_{s}", .{stem});
        const example_path = try std.fmt.allocPrint(b.allocator, "examples/{s}", .{entry.name});

        const example_exe = try createApp(b, exe_name, example_path, target, optimize, common_deps, .{});
        const run_example = b.addRunArtifact(example_exe);
        const example_step = b.step(step_name, step_desc);
        example_step.dependOn(&run_example.step);

        if (b.args) |args| {
            run_example.addArgs(args);
        }
    }
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const zevy_mem_dep = b.dependency("zevy_mem", .{
        .optimize = optimize,
        .target = target,
    });
    const zevy_mem = zevy_mem_dep.module("zevy_mem");

    const zevy_ecs_dep = b.dependency("zevy_ecs", .{
        .optimize = optimize,
        .target = target,
    });
    const zevy_ecs = zevy_ecs_dep.module("zevy_ecs");
    //const benchmark = zevy_ecs_dep.module("benchmark");
    const plugins = zevy_ecs_dep.module("plugins");

    const jok_dep = jok.getJokLibrary(b, target, optimize, .{});
    const sdl = jok.sdlModule(b, target, optimize, .{});

    const mod = b.addModule("zevy_jok", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zevy_mem", .module = zevy_mem },
            .{ .name = "zevy_ecs", .module = zevy_ecs },
            .{ .name = "plugins", .module = plugins },
            .{ .name = "jok", .module = jok_dep.module },
            .{ .name = "sdl", .module = sdl },
        },
    });

    const common_deps: CommonDeps = .{
        .zevy_mem = zevy_mem,
        .zevy_jok = mod,
        .zevy_ecs = zevy_ecs,
        .plugins = plugins,
        .jok = jok_dep.module,
        .sdl = sdl,
    };

    b.installArtifact(jok_dep.artifact);

    // Creates an executable that will run `test` blocks from the provided module.
    // Here `mod` needs to define a target, which is why earlier we made sure to
    // set the releative field.
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    // A run step that will run the test executable.
    const run_mod_tests = b.addRunArtifact(mod_tests);

    // A top level step for running all tests. dependOn can be called multiple
    // times and since the two run steps do not depend on one another, this will
    // make the two of them run in parallel.
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);

    try addExampleSteps(b, target, optimize, common_deps);

    try buildtools.deps.addDepsStep(b);
    try buildtools.fetch.addFetchStep(b, b.path("build.zig.zon"));
    buildtools.fetch.addGetStep(b);
    try buildtools.fmt.addFmtStep(b, true);
}
