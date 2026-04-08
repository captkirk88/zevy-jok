const std = @import("std");
const Io = std.Io;

const zevy_jok = @import("zevy_jok");
const jok = @import("jok");
const math = zevy_jok.math;
const ecs = @import("zevy_ecs");
const plugins = @import("plugins");
const benchmark = @import("benchmark");

const Stage = ecs.schedule.Stage;
const Stages = ecs.schedule.Stages;

var manager: ecs.Manager = undefined;
var scheduler: *ecs.schedule.Scheduler = undefined;
var plugin_man: plugins.PluginManager = undefined;

pub fn init(ctx: jok.Context) !void {
    const gpa = ctx.allocator();

    const RenderPlugin = zevy_jok.render.RenderPlugin;
    manager = try ecs.Manager.init(gpa);
    const _scheduler = try ecs.schedule.Scheduler.init(gpa);
    var scheduler_arc = try manager.addResource(ecs.schedule.Scheduler, _scheduler);
    defer scheduler_arc.deinit();
    plugin_man = plugins.PluginManager.init(gpa);

    try plugin_man.add(zevy_jok.window.WindowPlugin(ecs.DefaultParamRegistry), .init(ctx, .{}));
    try plugin_man.add(RenderPlugin(ecs.DefaultParamRegistry), .init(ctx));
    try plugin_man.build(&manager);

    var scheduler_lock = scheduler_arc.lockWrite();
    defer scheduler_lock.deinit();
    scheduler = scheduler_lock.get();
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
    try ctx.renderer().clear(jok.Color.black);
    try scheduler.runStages(&manager, Stage(Stages.PreDraw), Stage(Stages.PostDraw));

    const fps = ctx.fps();

    const label = try std.fmt.allocPrint(ctx.allocator(), "FPS: {d:.02}", .{fps});
    defer ctx.allocator().free(label);
    ctx.debugPrint(label, .{});
}

pub fn quit(ctx: jok.Context) void {
    _ = ctx;
    if (plugin_man.deinit(&manager)) |err| {
        for (err) |e| {
            std.log.err("Error deinitializing plugin {s}: {s}\n", .{ e.plugin, @errorName(e.err) });
        }
        plugin_man.allocator.free(err);
    }
    manager.deinit();
}

fn startup(commands: ecs.commands.Commands, win_res: ecs.ResMut(jok.Window)) !void {
    const window = win_res.get();
    const entity_count = 1000;
    var i: usize = 0;
    var prng = std.Random.DefaultPrng.init(0);
    const random = prng.random();
    while (i < entity_count) : (i += 1) {
        var ent = try commands.create();
        defer ent.deinit();
        _ = try ent.add(zevy_jok.components.shape.Shape, .circle(10.0));
        const color = jok.Color.rgb(
            random.int(u8),
            random.int(u8),
            random.int(u8),
        );
        _ = try ent.add(zevy_jok.components.Color, color);
        _ = try ent.add(zevy_jok.components.Transform, .translation(math.Vector2.new(
            random.float(f32) * window.getSize().getWidthFloat(),
            random.float(f32) * window.getSize().getHeightFloat(),
        )));
    }
}
