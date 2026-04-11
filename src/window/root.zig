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
    fullscreen_mode: FullscreenMode = .Windowed,
};

pub fn WindowPlugin(comptime EcsParamRegistry: ?type) type {
    return struct {
        const Self = @This();
        pub const Name: []const u8 = "WindowPlugin";

        __context: jok.Context = undefined,

        pub fn init(ctx: jok.Context, options: WindowOptions) Self {
            const window_size: jok.j2d.geom.Size = .{ .width = options.width, .height = options.height };
            ctx.window().setSize(window_size) catch {};
            ctx.window().setTitle(options.title) catch {};
            switch (options.fullscreen_mode) {
                .Exclusive => ctx.window().setFullscreen(true) catch {},
                .Borderless => unreachable, // Limited by jok's comptime config requirement
                .Windowed => ctx.window().setFullscreen(false) catch {},
            }
            return Self{
                .__context = ctx,
            };
        }

        pub fn build(self: *Self, manager: *ecs.Manager, plugins: *plugin.PluginManager) anyerror!void {
            _ = try manager.addResource(jok.Window, self.__context.window());
            _ = try manager.addResource(jok.Context, self.__context);
            _ = try manager.addResource(DeltaTime, 0.0);
            if (manager.getResource(ecs.schedule.Scheduler)) |scheduler_res| {
                var scheduler = scheduler_res.lockWrite();
                defer scheduler.deinit();
                scheduler.get().addSystem(manager, ecs.schedule.Stage(ecs.schedule.Stages.PreUpdate), updateDeltaTime, EcsParamRegistry orelse ecs.DefaultParamRegistry);
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
