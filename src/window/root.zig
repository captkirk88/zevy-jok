const std = @import("std");
const reflect = @import("zevy_reflect");
const ecs = @import("zevy_ecs");
const plugin = @import("plugins");
const jok = @import("jok");
const math = @import("../math.zig");

// RESOURCES
pub const Window = jok.Window;
pub const Context = jok.Context;
pub const DeltaTime = f32;

pub const FullscreenMode = enum {
    Exclusive,
    Borderless,
    Windowed,
};

pub const WindowOptions = struct {
    width: u32 = 1200,
    height: u32 = 800,
    title: [:0]const u8 = "Zevy Jok",
    fullscreen_mode: reflect.Change(FullscreenMode) = .init(.Windowed),

    pub fn deinit(self: *WindowOptions) void {
        self.fullscreen_mode.deinit();
    }
};

pub fn WindowPlugin(comptime EcsParamRegistry: ?type) type {
    const ParamRegistry = if (EcsParamRegistry) |t| t else ecs.DefaultParamRegistry;
    return struct {
        const Self = @This();
        pub const Name: []const u8 = "WindowPlugin";

        window_options: WindowOptions,
        __context: jok.Context = undefined,

        pub fn init(ctx: jok.Context, options: WindowOptions) Self {
            const window_size: jok.j2d.geom.Size = .{ .width = options.width, .height = options.height };
            ctx.window().setSize(window_size) catch {};
            ctx.window().setTitle(options.title) catch {};
            switch (options.fullscreen_mode.value()) {
                .Exclusive => ctx.window().setFullscreen(true) catch {},
                .Borderless => unreachable, // Limited by jok's comptime config requirement
                .Windowed => ctx.window().setFullscreen(false) catch {},
            }
            return Self{
                .window_options = options,
                .__context = ctx,
            };
        }

        pub fn build(self: *Self, manager: *ecs.Manager, plugins: *plugin.PluginManager) anyerror!void {
            _ = try manager.addResource(reflect.Change(WindowOptions), .init(self.window_options));
            _ = try manager.addResource(jok.Window, self.__context.window());
            _ = try manager.addResource(jok.Context, self.__context);
            _ = try manager.addResource(DeltaTime, 0.0);
            if (manager.getResource(ecs.schedule.Scheduler)) |scheduler_res| {
                var scheduler = scheduler_res.lockWrite();
                defer scheduler.deinit();

                scheduler.get().addSystem(manager, ecs.schedule.Stage(ecs.schedule.Stages.PreUpdate), updateDeltaTime, ParamRegistry);

                // Toggle fullscreen when F11 is pressed
                // Note: This system is not added because pressing f11 results in freezing the entire program
                //scheduler.get().addSystem(manager, ecs.schedule.Stage(ecs.schedule.Stages.Update), ecs.chain(.{ toggleFullscreen, changeWindowOptions }), ParamRegistry);
            }
            _ = plugins;
        }

        pub fn deinit(_: *Self, allocator: std.mem.Allocator, manager: *ecs.Manager) anyerror!void {
            _ = allocator;
            _ = manager;
        }
    };
}

const Commands = ecs.params.Commands;
const Res = ecs.params.Res;
const ResMut = ecs.params.ResMut;

fn updateDeltaTime(ctx: Res(jok.Context), dt: ResMut(DeltaTime)) !void {
    dt.get().* = ctx.get().deltaSeconds();
}

fn changeWindowOptions(window: ResMut(jok.Window), options_res: ResMut(reflect.Change(WindowOptions))) !void {
    const change = options_res.get();

    if (change.isChanged()) {
        const opts = change.get();
        const window_size: jok.j2d.geom.Size = .{ .width = opts.width, .height = opts.height };
        window.get().setSize(window_size) catch {};
        window.get().setTitle(opts.title) catch {};
        change.finish();
    }

    // Check the LIVE nested fullscreen_mode — do NOT copy it, or finish() won't take effect
    if (change.getConst().fullscreen_mode.isChanged()) {
        // change.isChanged() is false here (finished above or was never set)
        // so change.get() is safe — it won't panic
        const opts = change.get();
        switch (opts.fullscreen_mode.getConst().*) {
            .Exclusive => window.get().setFullscreen(true) catch |err| {
                std.log.err("Failed to set fullscreen mode: {s}", .{@errorName(err)});
            },
            .Borderless => unreachable, // Limited by jok's comptime config requirement
            .Windowed => window.get().setFullscreen(false) catch |err| {
                std.log.err("Failed to set windowed mode: {s}", .{@errorName(err)});
            },
        }
        // finish() on the LIVE opts.fullscreen_mode clears isChanged() for next frame
        opts.fullscreen_mode.finish();
    }
}

fn toggleFullscreen(options: ResMut(reflect.Change(WindowOptions)), state: ecs.params.Local(struct {
    prev: bool = false,
})) !void {
    const now = jok.io.getKeyboardState().isPressed(jok.io.Scancode.f11);
    defer {
        state.set(.{ .prev = now });
    }
    if (now and state.get().prev == false) {
        const win_opts = options.get().get();
        const current_mode = win_opts.fullscreen_mode.get();
        current_mode.* = switch (current_mode.*) {
            .Exclusive => FullscreenMode.Windowed,
            .Borderless => FullscreenMode.Windowed,
            .Windowed => FullscreenMode.Exclusive,
        };
    }
}

fn spawnTeapot(commands: Commands) !void {
    var entity = try commands.create();
    defer entity.deinit();
}
