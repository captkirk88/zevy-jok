const std = @import("std");
const ecs = @import("zevy_ecs");
const plugin = @import("plugins");
const jok = @import("jok");
const math = @import("../math.zig");

pub const WindowOptions = struct {
    width: u32 = 1200,
    height: u32 = 800,
};

pub fn WindowPlugin(comptime T: type) type {
    _ = T;
    return struct {
        const Self = @This();
        pub const Name: []const u8 = "WindowPlugin";

        window_size: jok.j2d.geom.Size = .{ .width = 1200, .height = 800 },
        context: jok.Context,

        pub fn init(ctx: jok.Context, options: WindowOptions) Self {
            return Self{
                .window_size = .{ .width = options.width, .height = options.height },
                .context = ctx,
            };
        }

        pub fn build(self: *Self, manager: *ecs.Manager, plugins: *plugin.PluginManager) anyerror!void {
            _ = try manager.addResource(jok.Window, self.context.window());
            _ = try manager.addResource(jok.Context, self.context);
            _ = plugins;
        }

        pub fn deinit(_: *Self, allocator: std.mem.Allocator, manager: *ecs.Manager) anyerror!void {
            _ = allocator;
            _ = manager;
        }
    };
}
