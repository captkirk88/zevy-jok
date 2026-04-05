const std = @import("std");
const Io = std.Io;
const ecs = @import("zevy_ecs");
const plugin = @import("plugins");
const jok = @import("jok");
const sdl = @import("sdl");
const batchers = @import("batch.zig");

pub fn RenderPlugin(comptime T: type) type {
    _ = T;
    return struct {
        const Self = @This();
        pub const Name: []const u8 = "RenderPlugin";

        ctx: jok.Context,

        pub fn init(ctx: jok.Context) Self {
            return Self{
                .ctx = ctx,
            };
        }

        pub fn build(_: *Self, manager: *ecs.Manager, plugins: *plugin.PluginManager) anyerror!void {
            const render_pipeline2d = try manager.getOrAddResource(RenderPipeline2D, .init(manager.allocator), null);
            _ = render_pipeline2d;
            _ = plugins;
        }

        pub fn deinit(_: *Self, allocator: std.mem.Allocator, manager: *ecs.Manager) anyerror!void {
            _ = allocator;
            _ = manager;
        }
    };
}

pub const RenderPipeline2D = struct {
    const Self = @This();

    batch: batchers.Batch(batchers.BatchType.@"2D"),

    pub fn init(allocator: std.mem.Allocator) Self {
        _ = allocator;
        return Self{
            .batch = .{},
        };
    }
};
