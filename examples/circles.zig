const std = @import("std");
const Io = std.Io;

const zevy_jok = @import("zevy_jok");
const jok = @import("jok");
const math = zevy_jok.math;
const ecs = @import("zevy_ecs");
const plugins = @import("plugins");

const Stage = ecs.schedule.Stage;
const Stages = ecs.schedule.Stages;
const Res = ecs.params.Res;
const ResMut = ecs.params.ResMut;
const Query = ecs.params.Query;
const Commands = ecs.params.Commands;

/// Example demonstrating a large number of circles bouncing around the screen, with one sphere in the center. Tests basic rendering, transform updates, and 3D shape support.
const ENTITY_COUNT = 10_000;

var manager: ecs.Manager = undefined;
var scheduler: *ecs.schedule.Scheduler = undefined;
var plugin_man: plugins.PluginManager = undefined;

// Config pub const required by jok if you want to configure.
pub const jok_exit_on_recv_esc = true; // Exit the application when the Escape key is pressed

pub fn init(ctx: jok.Context) !void {
    const gpa = ctx.allocator();

    manager = try ecs.Manager.init(gpa);
    const _scheduler = try ecs.schedule.Scheduler.init(gpa);
    var scheduler_arc = try manager.addResource(ecs.schedule.Scheduler, _scheduler);
    defer scheduler_arc.deinit();
    plugin_man = plugins.PluginManager.init(gpa);

    try addPlugins(ctx);

    var scheduler_lock = scheduler_arc.lockWrite();
    {
        defer scheduler_lock.deinit();
        scheduler = scheduler_lock.get();

        // Add systems to the scheduler
        scheduler.addSystem(&manager, Stage(Stages.Startup), startup, ecs.DefaultParamRegistry);
        scheduler.addSystem(&manager, Stage(Stages.Update), moveCircles, ecs.DefaultParamRegistry);
        scheduler.addSystem(&manager, Stage(Stages.Update), centerSpheres, ecs.DefaultParamRegistry);

        // Run the startup stage immediately to initialize the scene before the first frame is drawn.
        const eg = scheduler.runStages(&manager, Stage(Stages.PreStartup), Stage(Stages.Startup));
        try eg.throw();
    }
}

pub fn addPlugins(ctx: jok.Context) !void {
    const window_config: zevy_jok.window.WindowOptions = .{
        .fullscreen_mode = .init(.Windowed),
        .title = "Circles!",
    };
    try addPlugin(zevy_jok.WindowPlugin(null), .init(ctx, window_config));
    try addPlugin(zevy_jok.RenderPlugin(null), .init(ctx));
    try plugin_man.build(&manager);
}

pub fn addPlugin(comptime PluginType: type, plugin: PluginType) !void {
    try plugin_man.add(PluginType, plugin);
}

pub fn event(ctx: jok.Context, e: jok.Event) !void {
    _ = ctx;
    _ = e;
}

pub fn update(ctx: jok.Context) !void {
    _ = ctx;
    const eg = scheduler.runStages(&manager, Stage(Stages.PreUpdate), Stage(Stages.PostUpdate));
    try eg.throw();
}

pub fn draw(ctx: jok.Context) !void {
    try ctx.renderer().clear(jok.Color.black);
    const eg = scheduler.runStages(&manager, Stage(Stages.PreDraw), Stage(Stages.PostDraw));
    try eg.throw();

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

fn startup(commands: Commands, win_res: ResMut(jok.Window), ctx_res: ResMut(jok.Context)) !void {
    {
        const ctx = ctx_res.get().*;
        var cam = try commands.create();
        defer cam.deinit();
        try cam.add(zevy_jok.components.Camera, .init(ctx, .orthographic));
    }
    const window = win_res.get();
    const window_size = window.getSize();

    var i: usize = 0;
    var prng = std.Random.DefaultPrng.init(0);
    const random = prng.random();
    while (i < ENTITY_COUNT) : (i += 1) {
        var ent = try commands.create();
        defer ent.deinit();
        try ent.add(zevy_jok.components.shape.Shape, .circle(10.0));
        try ent.add(zevy_jok.components.Color, jok.Color.rgb(
            random.int(u8),
            random.int(u8),
            random.int(u8),
        ));
        try ent.add(zevy_jok.components.Transform, .translation(math.Vector2.new(
            random.float(f32) * window_size.getWidthFloat(),
            random.float(f32) * window_size.getHeightFloat(),
        )));
        const rand_vel = randVector2(&prng, 50);
        try ent.add(zevy_jok.components.Velocity, rand_vel);
    }

    try createSphere(commands);
}

fn moveCircles(
    query: Query(struct {
        velocity: zevy_jok.components.Velocity,
        transform: zevy_jok.components.Transform,
    }),
    dt: Res(zevy_jok.window.DeltaTime),
    window: Res(jok.Window),
) !void {
    const bounds = math.Vector2.new(window.get().getSize().getWidthFloat(), window.get().getSize().getHeightFloat());
    const delta = dt.get().*;
    while (query.next()) |q| {
        const vel: *zevy_jok.components.Velocity = q.velocity;
        const transform: *zevy_jok.components.Transform = q.transform;
        const new_vec = math.Vector2.mul(vel.*, .new(delta, delta));
        const old_pos = transform.getTranslation();
        if (old_pos.x() + new_vec.x() < 0 or old_pos.x() + new_vec.x() > bounds.x()) {
            vel.* = math.Vector2.mul(vel.*, .new(-1, 1));
        }
        if (old_pos.y() + new_vec.y() < 0 or old_pos.y() + new_vec.y() > bounds.y()) {
            vel.* = math.Vector2.mul(vel.*, .new(1, -1));
        }
        const vel_after = math.Vector2.mul(vel.*, .new(delta, delta));
        _ = transform.translate(vel_after);
    }
}

fn centerSpheres(
    query: Query(struct {
        shape: zevy_jok.components.shape.Shape,
        transform: zevy_jok.components.Transform,
    }),
) !void {
    while (query.next()) |q| {
        const shape: *zevy_jok.components.shape.Shape = q.shape;
        if (!shape.is3D()) continue;

        switch (shape.*) {
            .Sphere => {
                const transform: *zevy_jok.components.Transform = q.transform;
                transform.* = .translation(math.Vector2.zero);
            },
            else => {},
        }
    }
}

fn createSphere(commands: Commands) !void {
    var ent = try commands.create();
    defer ent.deinit();
    const transform = zevy_jok.components.Transform.translation(math.Vector2.zero);
    try ent.add(zevy_jok.components.Transform, transform);
    try ent.add(zevy_jok.components.shape.Shape, .sphere(32.0, transform.getTranslation()));
}

fn randVector2(random: *std.Random.DefaultPrng, range: f32) math.Vector2 {
    const rand = random.random();
    return math.Vector2.new(
        rand.float(f32) * range - range / 2,
        rand.float(f32) * range - range / 2,
    );
}
