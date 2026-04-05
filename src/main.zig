const std = @import("std");
const Io = std.Io;

const zevy_jok = @import("zevy_jok");
const jok = @import("jok");
const ecs = @import("zevy_ecs");
const plugins = @import("plugins");
const benchmark = @import("benchmark");

const Stage = ecs.schedule.Stage;
const Stages = ecs.schedule.Stages;

var manager: ecs.Manager = undefined;
var scheduler: ecs.schedule.Scheduler = undefined;
var plugin_man: plugins.PluginManager = undefined;

pub fn init(ctx: jok.Context) !void {
    const gpa = ctx.allocator();

    const RenderPlugin = zevy_jok.render.RenderPlugin;
    manager = try ecs.Manager.init(gpa);
    scheduler = try ecs.schedule.Scheduler.init(gpa);
    plugin_man = plugins.PluginManager.init(gpa);

    try plugin_man.add(zevy_jok.window.WindowPlugin(ecs.DefaultParamRegistry), .init(ctx, .{}));
    try plugin_man.add(RenderPlugin(ecs.DefaultParamRegistry), .init(ctx));
    try plugin_man.build(&manager);

    scheduler.addSystem(&manager, Stage(Stages.Startup), startup, ecs.DefaultParamRegistry);
    try scheduler.runStages(&manager, Stage(Stages.PreStartup), Stage(Stages.Startup));
}

pub fn event(ctx: jok.Context, e: jok.Event) !void {
    _ = ctx;
    _ = e;
}

pub fn update(ctx: jok.Context) !void {
    _ = ctx;

    try scheduler.runStages(&manager, Stage(Stages.PreUpdate), Stage(Stages.PostUpdate));
}

pub fn draw(ctx: jok.Context) !void {
    _ = ctx;

    try scheduler.runStages(&manager, Stage(Stages.PreDraw), Stage(Stages.PostDraw));
}

pub fn quit(ctx: jok.Context) void {
    _ = ctx;
    manager.deinit();
    scheduler.deinit();
    if (plugin_man.deinit(&manager)) |err| for (err) |e| {
        std.log.err("Error deinitializing plugin {s}: {s}\n", .{ e.plugin, @errorName(e.err) });
    };
}

fn startup(win_res: ecs.params.ResMut(zevy_jok.window.Window)) !void {
    const window = win_res.get();
    try window.window.minimize();
}
