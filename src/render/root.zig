const std = @import("std");
const Io = std.Io;
const ecs = @import("zevy_ecs");

pub fn RenderPlugin(comptime T: type) type {
    return T;
}
