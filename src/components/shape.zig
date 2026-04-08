const jok = @import("jok");
const ecs = @import("zevy_ecs");

pub const Shape = union(enum) {
    Circle: jok.j2d.geom.Circle,
    Rectangle: jok.j2d.geom.Rectangle,
    Triangle: jok.j2d.geom.Triangle,
    Ellipse: jok.j2d.geom.Ellipse,
    Line: jok.j2d.geom.Line,
    Point: jok.j2d.geom.Point,
    Ray: jok.j2d.geom.Ray,

    pub fn circle(radius: f32) Shape {
        return .{ .Circle = .{ .radius = radius } };
    }

    pub fn rect(width: f32, height: f32) Shape {
        return .{ .Rectangle = .{ .width = width, .height = height } };
    }

    pub fn triangle(a: jok.j2d.geom.Vec2, b: jok.j2d.geom.Vec2, c: jok.j2d.geom.Vec2) Shape {
        return .{ .Triangle = .{ .a = a, .b = b, .c = c } };
    }

    pub fn ellipse(rx: f32, ry: f32) Shape {
        return .{ .Ellipse = .{ .rx = rx, .ry = ry } };
    }

    pub fn line(start: jok.j2d.geom.Vec2, end: jok.j2d.geom.Vec2) Shape {
        return .{ .Line = .{ .start = start, .end = end } };
    }

    pub fn point(pos: jok.j2d.Vector) Shape {
        return .{ .Point = .{ .pos = pos } };
    }

    pub fn ray(origin: jok.j2d.Vector, direction: jok.j2d.Vector) Shape {
        return .{ .Ray = .{ .origin = origin, .direction = direction } };
    }

    pub fn setOrigin(self: *Shape, origin: jok.j2d.Vector) void {
        switch (self.*) {
            .Circle => |*c| {
                c.center = origin.toPoint();
            },
            .Rectangle => |*r| {
                r.x = origin.x();
                r.y = origin.y();
            },
            .Triangle => |*tri| {
                tri.p0 = origin.toPoint();
            },
            .Ellipse => |*e| {
                e.center = origin.toPoint();
            },
            .Line => |*l| {
                l.p0 = origin.toPoint();
            },
            .Point => |*p| {
                p.x = origin.x();
                p.y = origin.y();
            },
            .Ray => |*ry| {
                ry.origin = origin.toPoint();
            },
        }
    }
};
