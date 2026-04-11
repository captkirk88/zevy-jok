const std = @import("std");
const ecs = @import("zevy_ecs");
const plugin = @import("plugins");
const jok = @import("jok");
pub const batchers = @import("batch.zig");
pub const components = @import("../components/root.zig");
const math = @import("../math.zig");

pub fn RenderPlugin(comptime EcsParamRegistry: ?type) type {
    _ = EcsParamRegistry;
    return struct {
        const Self = @This();
        pub const Name: []const u8 = "RenderPlugin";

        ctx: jok.Context,

        pub fn init(ctx: jok.Context) Self {
            return Self{
                .ctx = ctx,
            };
        }

        pub fn build(self: *Self, manager: *ecs.Manager, plugins: *plugin.PluginManager) anyerror!void {
            _ = plugins;
            _ = try manager.addResource(batchers.Batch, batchers.Batch.new(self.ctx));
            if (manager.getResource(ecs.schedule.Scheduler)) |scheduler| {
                const sched = scheduler.lockWrite();
                defer sched.deinit();

                sched.get().addSystem(manager, ecs.schedule.Stage(ecs.schedule.Stages.PreDraw), beginRender2d, ecs.DefaultParamRegistry);
            }
        }

        pub fn deinit(_: *Self, allocator: std.mem.Allocator, manager: *ecs.Manager) anyerror!void {
            _ = allocator;
            _ = manager;
        }
    };
}

const ResMut = ecs.params.ResMut;
const Query = ecs.params.Query;

fn beginRender2d(batcher: ResMut(batchers.Batch), query_shapes: Query(struct {
    shape: components.shape.Shape,
    transform: components.Transform,
    color: ?components.Color,
})) !void {
    const batch = batcher.get();
    const rend_2d = batch.begin2d();
    defer batch.end2d();

    while (query_shapes.next()) |q| {
        const color = q.color orelse &jok.Color.white;
        const shape: *components.shape.Shape = q.shape;
        const transform: *components.Transform = q.transform;
        shape.setOrigin(.new(transform.getX(), transform.getY()));
        switch (shape.*) {
            .Circle => |circle| {
                try rend_2d.circleFilled(circle, color.*, .{});
            },
            .Rectangle => |rect| {
                _ = rect;
            },
            .Triangle => |tri| {
                _ = tri;
            },
            else => {},
        }
    }
}
