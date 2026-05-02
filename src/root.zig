//! zevy-jok
const std = @import("std");
const Io = std.Io;

pub const render = @import("render/root.zig");
pub const Batch = render.batchers.Batch;
pub const RenderPlugin = render.RenderPlugin;

pub const assets = @import("assets/root.zig");

pub const window = @import("window/root.zig");
pub const WindowPlugin = window.WindowPlugin;

pub const components = @import("components/root.zig");
pub const jok = @import("jok");
pub const sdl = @import("sdl");

pub const math = @import("math.zig");

pub const vendor = struct {
    pub const jok = @import("jok");
    pub const sdl = @import("sdl");
};

test {
    std.testing.refAllDecls(render);
    std.testing.refAllDecls(assets);
    std.testing.refAllDecls(window);
    std.testing.refAllDecls(components);
    std.testing.refAllDecls(components.shape);
}
