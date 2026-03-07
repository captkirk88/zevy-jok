const std = @import("std");
const Io = std.Io;

const zevy_jok = @import("zevy_jok");
const ecs = @import("zevy_ecs");
const plugins = @import("plugins");
const benchmark = @import("benchmark");

pub fn main(init: std.process.Init) !void {
    const RenderPlugin = zevy_jok.render.RenderPlugin(ecs.DefaultParamRegistry);
    var manager = try ecs.Manager.init(init.gpa);
    defer manager.deinit();
    var scheduler = try ecs.schedule.Scheduler.init(init.gpa);
    defer scheduler.deinit();
    var plugin_man = plugins.PluginManager.init(init.gpa);
    defer {
        if (plugin_man.deinit(&manager)) |err| for (err) |e| {
            std.debug.print("Error deinitializing plugin: {s}\n", .{e});
        };
    }
    try plugin_man.add(RenderPlugin, RenderPlugin{});
    try scheduler.runStages(&manager, ecs.schedule.Stages.First.priority, ecs.schedule.Stages.Last.priority);
}
