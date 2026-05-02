const std = @import("std");
const jok = @import("jok");
const ecs = @import("zevy_ecs");
const reflect = @import("zevy_reflect");

pub const Shape = union(enum) {
    Circle: jok.j2d.geom.Circle,
    Rectangle: jok.j2d.geom.Rectangle,
    Triangle: jok.j2d.geom.Triangle,
    Ellipse: jok.j2d.geom.Ellipse,
    Line: jok.j2d.geom.Line,
    Point: jok.j2d.geom.Point,
    Ray: jok.j2d.geom.Ray,
    Sphere: jok.j3d.geom.Sphere,
    Box: jok.j3d.geom.AABB,
    Triangle3D: jok.j3d.geom.Triangle,

    const Self = @This();

    pub fn circle(radius: f32) Shape {
        return .{ .Circle = .{ .radius = radius } };
    }

    pub fn rect(width: f32, height: f32) Shape {
        return .{ .Rectangle = .{ .x = 0, .y = 0, .width = width, .height = height } };
    }

    pub fn triangle(a: jok.j2d.geom.Point, b: jok.j2d.geom.Point, c: jok.j2d.geom.Point) Shape {
        return .{ .Triangle = .{ .p0 = a, .p1 = b, .p2 = c } };
    }

    pub fn ellipse(rx: f32, ry: f32) Shape {
        return .{ .Ellipse = .{ .radius = .{ .x = rx, .y = ry } } };
    }

    pub fn line(start: jok.j2d.geom.Point, end: jok.j2d.geom.Point) Shape {
        return .{ .Line = .{ .p0 = start, .p1 = end } };
    }

    pub fn point(pos: jok.j2d.Vector) Shape {
        return .{ .Point = pos.toPoint() };
    }

    pub fn ray(origin: jok.j2d.Vector, direction: jok.j2d.Vector) Shape {
        return .{ .Ray = .{ .origin = origin.toPoint(), .dir = direction.toPoint() } };
    }

    pub fn sphere(radius: f32, center: jok.j3d.Vector) Shape {
        return .{ .Sphere = .{ .radius = radius, .center = center.toArray() } };
    }

    pub fn box(size: jok.j3d.Vector, center: jok.j3d.Vector) Shape {
        const half_size = jok.j3d.Vector.new(size.x() / 2, size.y() / 2, size.z() / 2);
        return .{ .Box = .{ .min = center.sub(half_size).toArray(), .max = center.add(half_size).toArray() } };
    }

    pub fn triangle3D(a: jok.j3d.Vector, b: jok.j3d.Vector, c: jok.j3d.Vector) Shape {
        return .{ .Triangle3D = .{ .v0 = a.toArray(), .v1 = b.toArray(), .v2 = c.toArray() } };
    }

    pub fn is2D(self: *const Self) bool {
        return switch (self.*) {
            .Circle, .Rectangle, .Triangle, .Ellipse, .Line, .Point, .Ray => true,
            .Sphere, .Box, .Triangle3D => false,
        };
    }

    pub fn is3D(shape: anytype) bool {
        return !is2D(shape);
    }

    pub fn setOrigin(self: *Self, origin: anytype) void {
        switch (@TypeOf(origin)) {
            jok.j2d.Vector => switch (self.*) {
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
                else => {},
            },
            jok.j3d.Vector => switch (self.*) {
                .Sphere => |*s| {
                    s.center = origin.toArray();
                },
                .Box => |*b| {
                    const min = jok.j3d.Vector.fromSlice(&b.min);
                    const max = jok.j3d.Vector.fromSlice(&b.max);
                    const half_size = max.sub(min).scale(0.5);
                    b.min = origin.sub(half_size).toArray();
                    b.max = origin.add(half_size).toArray();
                },
                .Triangle3D => |*t| {
                    t.v0 = origin.toArray();
                },
                else => {},
            },
            else => @compileError("Shape.setOrigin expects jok.j2d.Vector or jok.j3d.Vector"),
        }
    }
};

test "Shape.circle constructs a 2D circle" {
    var shape = Shape.circle(12.5);

    try std.testing.expect(shape.is2D());
    try std.testing.expect(!shape.is3D());

    switch (shape) {
        .Circle => |circle| {
            try std.testing.expectEqual(@as(f32, 12.5), circle.radius);
        },
        else => unreachable,
    }
}

test "Shape.rect constructs a 2D rectangle" {
    var shape = Shape.rect(30.0, 45.0);

    try std.testing.expect(shape.is2D());
    try std.testing.expect(!shape.is3D());

    switch (shape) {
        .Rectangle => |rect| {
            try std.testing.expectEqual(@as(f32, 30.0), rect.width);
            try std.testing.expectEqual(@as(f32, 45.0), rect.height);
        },
        else => unreachable,
    }
}

test "Shape.triangle constructs a 2D triangle" {
    const a = jok.j2d.Vector.new(1.0, 2.0).toPoint();
    const b = jok.j2d.Vector.new(3.0, 4.0).toPoint();
    const c = jok.j2d.Vector.new(5.0, 6.0).toPoint();
    var shape = Shape.triangle(a, b, c);

    try std.testing.expect(shape.is2D());
    try std.testing.expect(!shape.is3D());

    switch (shape) {
        .Triangle => |triangle| {
            try std.testing.expectEqualDeep(a, triangle.p0);
            try std.testing.expectEqualDeep(b, triangle.p1);
            try std.testing.expectEqualDeep(c, triangle.p2);
        },
        else => unreachable,
    }
}

test "Shape.ellipse constructs a 2D ellipse" {
    var shape = Shape.ellipse(7.0, 9.0);

    try std.testing.expect(shape.is2D());
    try std.testing.expect(!shape.is3D());

    switch (shape) {
        .Ellipse => |ellipse| {
            try std.testing.expectEqual(@as(f32, 7.0), ellipse.radius.x);
            try std.testing.expectEqual(@as(f32, 9.0), ellipse.radius.y);
        },
        else => unreachable,
    }
}

test "Shape.line constructs a 2D line" {
    const start = jok.j2d.Vector.new(-1.0, 2.0).toPoint();
    const end = jok.j2d.Vector.new(3.5, -4.5).toPoint();
    var shape = Shape.line(start, end);

    try std.testing.expect(shape.is2D());
    try std.testing.expect(!shape.is3D());

    switch (shape) {
        .Line => |line| {
            try std.testing.expectEqualDeep(start, line.p0);
            try std.testing.expectEqualDeep(end, line.p1);
        },
        else => unreachable,
    }
}

test "Shape.point constructs a 2D point" {
    const pos = jok.j2d.Vector.new(8.0, 11.0);
    var shape = Shape.point(pos);

    try std.testing.expect(shape.is2D());
    try std.testing.expect(!shape.is3D());

    switch (shape) {
        .Point => |point| {
            try std.testing.expectEqualDeep(pos, point.toVector());
        },
        else => unreachable,
    }
}

test "Shape.ray constructs a 2D ray" {
    const origin = jok.j2d.Vector.new(2.0, 4.0);
    const direction = jok.j2d.Vector.new(1.0, 0.0);
    var shape = Shape.ray(origin, direction);

    try std.testing.expect(shape.is2D());
    try std.testing.expect(!shape.is3D());

    switch (shape) {
        .Ray => |ray| {
            try std.testing.expectEqualDeep(origin.toPoint(), ray.origin);
            try std.testing.expectEqualDeep(direction.toPoint(), ray.dir);
        },
        else => unreachable,
    }
}

test "Shape.sphere constructs a 3D sphere" {
    const center = jok.j3d.Vector.new(1.0, 2.0, 3.0);
    var shape = Shape.sphere(6.5, center);

    try std.testing.expect(!shape.is2D());
    try std.testing.expect(shape.is3D());

    switch (shape) {
        .Sphere => |sphere| {
            try std.testing.expectEqual(@as(f32, 6.5), sphere.radius);
            try std.testing.expectEqualDeep(center.toArray(), sphere.center);
        },
        else => unreachable,
    }
}

test "Shape.box constructs a 3D box centered on the given point" {
    const size = jok.j3d.Vector.new(10.0, 6.0, 4.0);
    const center = jok.j3d.Vector.new(8.0, -2.0, 1.0);
    var shape = Shape.box(size, center);

    try std.testing.expect(!shape.is2D());
    try std.testing.expect(shape.is3D());

    switch (shape) {
        .Box => |box| {
            try std.testing.expectEqualDeep(jok.j3d.Vector.new(3.0, -5.0, -1.0).toArray(), box.min);
            try std.testing.expectEqualDeep(jok.j3d.Vector.new(13.0, 1.0, 3.0).toArray(), box.max);
        },
        else => unreachable,
    }
}

test "Shape.triangle3D constructs a 3D triangle" {
    const a = jok.j3d.Vector.new(1.0, 0.0, 0.0);
    const b = jok.j3d.Vector.new(0.0, 1.0, 0.0);
    const c = jok.j3d.Vector.new(0.0, 0.0, 1.0);
    var shape = Shape.triangle3D(a, b, c);

    try std.testing.expect(!shape.is2D());
    try std.testing.expect(shape.is3D());

    switch (shape) {
        .Triangle3D => |triangle| {
            try std.testing.expectEqualDeep(a.toArray(), triangle.v0);
            try std.testing.expectEqualDeep(b.toArray(), triangle.v1);
            try std.testing.expectEqualDeep(c.toArray(), triangle.v2);
        },
        else => unreachable,
    }
}

test "Shape.is2D and Shape.is3D work at comptime" {
    comptime {
        if (!Shape.circle(32).is2D()) {
            @compileError("Circle should be 2D");
        }
        if (Shape.circle(32).is3D()) {
            @compileError("Circle should not be 3D");
        }
        if (Shape.triangle3D(.zero, .zero, .zero).is2D()) {
            @compileError("Triangle3D should not be 2D");
        }
        if (!Shape.triangle3D(.zero, .zero, .zero).is3D()) {
            @compileError("Triangle3D should be 3D");
        }
    }
}
