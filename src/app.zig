const std = @import("std");
const ecs = @import("zevy_ecs");
const plugin = @import("plugins");
const jok = @import("jok");
const math = @import("math.zig");

pub const AppExit = union(enum(u8)) {
    Success = 0,
    Failure: anyerror = anyerror,
};

pub const App = opaque {
    pub const Inner = struct {
        manager: ecs.Manager,
        scheduler: *ecs.schedule.Scheduler,
        plugins: plugin.PluginManager,
    };

    pub fn init(ctx: jok.Context) !App {
        const gpa = ctx.allocator();

        const manager = try ecs.Manager.init(gpa);
        const _scheduler = try ecs.schedule.Scheduler.init(gpa);
        var scheduler_arc = try manager.addResource(ecs.schedule.Scheduler, _scheduler);
        defer scheduler_arc.deinit();

        var scheduler_lock = scheduler_arc.lockWrite();
        defer scheduler_lock.deinit();
        const scheduler = scheduler_lock.get();

        const plugin_man = plugin.PluginManager.init(gpa);

        const inner = try ctx.allocator().create(Inner);
        inner.* = Inner{
            .manager = manager,
            .scheduler = scheduler,
            .plugins = plugin_man,
        };
        return @ptrCast(inner);
    }

    pub fn deinit(self: *App, _: std.mem.Allocator) void {
        var inner: *Inner = @ptrCast(self);
        inner.manager.deinit();
        inner.scheduler.deinit();
    }

    pub fn addPlugin(self: *App, comptime PluginType: type, plug: PluginType) error{
        PluginAlreadyExists,
        OutOfMemory,
    }!void {
        const inner: *Inner = @ptrCast(self);
        try inner.plugins.add(PluginType, plug);
    }
};
