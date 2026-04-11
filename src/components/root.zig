pub const shape = @import("shape.zig");
const jok = @import("jok");

pub const Color = jok.Color;

const math = @import("../math.zig");

pub const Position = math.Vector2;
pub const Velocity = math.Vector2;
pub const Scale = math.Vector2;
pub const Rotation = f32;

pub const Transform = math.Transform;

pub const Camera = struct {
    pub const Projection = union(enum) {
        orthographic: void,
        perspective: void,
    };

    projection: Projection,
    camera: jok.j3d.Camera,

    pub fn init(ctx: jok.Context, projection: Projection) Camera {
        const window = ctx.window();
        const size = window.getSize();
        const aspect_ratio = size.getWidthFloat() / size.getHeightFloat();

        const pos: [3]f32 = .{ 0.0, 0.0, 1.0 };
        const target = [3]f32{ 0.0, 0.0, 0.0 };
        const view: jok.j3d.Camera.ViewFrustum = blk: {
            switch (projection) {
                .orthographic => break :blk .{ .orthographic = .{
                    .width = size.getWidthFloat(),
                    .height = size.getHeightFloat(),
                    .near = 0.01,
                    .far = 100.0,
                } },
                .perspective => break :blk .{ .perspective = .{
                    .fov = math.degToRad(60.0),
                    .aspect_ratio = aspect_ratio,
                    .near = 0.01,
                    .far = 100.0,
                } },
            }
        };
        const camera = jok.j3d.Camera.fromPositionAndTarget(view, pos, target);
        return Camera{
            .projection = projection,
            .camera = camera,
        };
    }
};
