const std = @import("std");
const ecs = @import("zevy_ecs");
const plugin = @import("plugins");
const jok = @import("jok");
pub const batchers = @import("batch.zig");
pub const components = @import("../components/root.zig");
const math = @import("../math.zig");

pub fn RenderPlugin(comptime EcsParamRegistry: ?type) type {
    const ParamRegistry = if (EcsParamRegistry) |t| t else ecs.DefaultParamRegistry;
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

                sched.get().addSystem(manager, ecs.schedule.Stage(ecs.schedule.Stages.PreDraw), renderShapes, ParamRegistry);
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

const RenderItem = struct {
    shape: *components.shape.Shape,
    transform: *components.Transform,
    color: components.Color,
};

const sphere_stacks = 8;
const sphere_slices = 16;
const max_shape_positions = 2 + (sphere_stacks - 1) * (sphere_slices + 1);
const max_shape_indices = sphere_slices * 6 * (sphere_stacks - 1);

const ShapeTriangles = struct {
    positions: [max_shape_positions][3]f32 = undefined,
    normals: [max_shape_positions][3]f32 = undefined,
    indices: [max_shape_indices]u32 = undefined,
    position_len: usize = 0,
    index_len: usize = 0,

    fn appendVertexAssumeCapacity(self: *ShapeTriangles, position: [3]f32, normal: [3]f32) u32 {
        const index: u32 = @intCast(self.position_len);
        self.positions[self.position_len] = position;
        self.normals[self.position_len] = normal;
        self.position_len += 1;
        return index;
    }

    fn appendTriangleIndicesAssumeCapacity(self: *ShapeTriangles, idx0: u32, idx1: u32, idx2: u32) void {
        self.indices[self.index_len] = idx0;
        self.indices[self.index_len + 1] = idx1;
        self.indices[self.index_len + 2] = idx2;
        self.index_len += 3;
    }

    fn appendFlatTriangleAssumeCapacity(self: *ShapeTriangles, v0: [3]f32, v1: [3]f32, v2: [3]f32) void {
        const normal = jok.j3d.geom.Triangle.init(v0, v1, v2).normal();
        const idx0 = self.appendVertexAssumeCapacity(v0, normal);
        const idx1 = self.appendVertexAssumeCapacity(v1, normal);
        const idx2 = self.appendVertexAssumeCapacity(v2, normal);
        self.appendTriangleIndicesAssumeCapacity(idx0, idx1, idx2);
    }

    fn appendFlatQuadAssumeCapacity(self: *ShapeTriangles, v0: [3]f32, v1: [3]f32, v2: [3]f32, v3: [3]f32) void {
        const base = self.appendVertexAssumeCapacity(v0, jok.j3d.geom.Triangle.init(v0, v1, v2).normal());
        const normal = self.normals[base];
        const idx1 = self.appendVertexAssumeCapacity(v1, normal);
        const idx2 = self.appendVertexAssumeCapacity(v2, normal);
        const idx3 = self.appendVertexAssumeCapacity(v3, normal);
        self.appendTriangleIndicesAssumeCapacity(base, idx1, idx2);
        self.appendTriangleIndicesAssumeCapacity(base, idx2, idx3);
    }

    fn positionsSlice(self: *const ShapeTriangles) []const [3]f32 {
        return self.positions[0..self.position_len];
    }

    fn normalsSlice(self: *const ShapeTriangles) []const [3]f32 {
        return self.normals[0..self.position_len];
    }

    fn indicesSlice(self: *const ShapeTriangles) []const u32 {
        return self.indices[0..self.index_len];
    }
};

fn buildTrianglesFromShape(shape: *const components.shape.Shape) ShapeTriangles {
    var triangles: ShapeTriangles = .{};

    switch (shape.*) {
        .Sphere => |sphere| {
            const center = jok.j3d.Vector.fromSlice(&sphere.center);
            const top = triangles.appendVertexAssumeCapacity(
                center.add(jok.j3d.Vector.new(0, sphere.radius, 0)).toArray(),
                .{ 0, 1, 0 },
            );

            var ring_starts: [sphere_stacks - 1]u32 = undefined;
            var stack: usize = 1;
            while (stack < sphere_stacks) : (stack += 1) {
                const phi = std.math.pi * @as(f32, @floatFromInt(stack)) / @as(f32, @floatFromInt(sphere_stacks));
                const y = @cos(phi);
                const radius_xz = @sin(phi);

                ring_starts[stack - 1] = @intCast(triangles.position_len);

                var slice: usize = 0;
                while (slice <= sphere_slices) : (slice += 1) {
                    const theta = 2.0 * std.math.pi * @as(f32, @floatFromInt(slice)) / @as(f32, @floatFromInt(sphere_slices));
                    const normal = [3]f32{
                        radius_xz * @cos(theta),
                        y,
                        radius_xz * @sin(theta),
                    };
                    const position = center.add(jok.j3d.Vector.new(
                        normal[0] * sphere.radius,
                        normal[1] * sphere.radius,
                        normal[2] * sphere.radius,
                    )).toArray();
                    _ = triangles.appendVertexAssumeCapacity(position, normal);
                }
            }

            const bottom = triangles.appendVertexAssumeCapacity(
                center.add(jok.j3d.Vector.new(0, -sphere.radius, 0)).toArray(),
                .{ 0, -1, 0 },
            );

            const first_ring = ring_starts[0];
            var slice: usize = 0;
            while (slice < sphere_slices) : (slice += 1) {
                const idx0 = first_ring + @as(u32, @intCast(slice));
                const idx1 = first_ring + @as(u32, @intCast(slice + 1));
                triangles.appendTriangleIndicesAssumeCapacity(top, idx0, idx1);
            }

            stack = 0;
            while (stack + 1 < sphere_stacks - 1) : (stack += 1) {
                const ring0 = ring_starts[stack];
                const ring1 = ring_starts[stack + 1];

                slice = 0;
                while (slice < sphere_slices) : (slice += 1) {
                    const current0 = ring0 + @as(u32, @intCast(slice));
                    const current1 = ring0 + @as(u32, @intCast(slice + 1));
                    const next0 = ring1 + @as(u32, @intCast(slice));
                    const next1 = ring1 + @as(u32, @intCast(slice + 1));
                    triangles.appendTriangleIndicesAssumeCapacity(current0, next0, current1);
                    triangles.appendTriangleIndicesAssumeCapacity(current1, next0, next1);
                }
            }

            const last_ring = ring_starts[sphere_stacks - 2];
            slice = 0;
            while (slice < sphere_slices) : (slice += 1) {
                const idx0 = last_ring + @as(u32, @intCast(slice));
                const idx1 = last_ring + @as(u32, @intCast(slice + 1));
                triangles.appendTriangleIndicesAssumeCapacity(idx1, idx0, bottom);
            }
        },
        .Box => |box| {
            const min = box.min;
            const max = box.max;

            const v000 = [3]f32{ min[0], min[1], min[2] };
            const v001 = [3]f32{ min[0], min[1], max[2] };
            const v010 = [3]f32{ min[0], max[1], min[2] };
            const v011 = [3]f32{ min[0], max[1], max[2] };
            const v100 = [3]f32{ max[0], min[1], min[2] };
            const v101 = [3]f32{ max[0], min[1], max[2] };
            const v110 = [3]f32{ max[0], max[1], min[2] };
            const v111 = [3]f32{ max[0], max[1], max[2] };

            triangles.appendFlatQuadAssumeCapacity(v001, v101, v111, v011);
            triangles.appendFlatQuadAssumeCapacity(v100, v000, v010, v110);
            triangles.appendFlatQuadAssumeCapacity(v000, v001, v011, v010);
            triangles.appendFlatQuadAssumeCapacity(v101, v100, v110, v111);
            triangles.appendFlatQuadAssumeCapacity(v010, v011, v111, v110);
            triangles.appendFlatQuadAssumeCapacity(v000, v100, v101, v001);
        },
        .Triangle3D => |triangle| {
            triangles.appendFlatTriangleAssumeCapacity(triangle.v0, triangle.v1, triangle.v2);
        },
        else => {},
    }

    return triangles;
}

fn renderShapes(batcher: ResMut(batchers.Batch), query_shapes: Query(struct {
    shape: components.shape.Shape,
    transform: components.Transform,
    color: ?components.Color,
}), query_cameras: Query(struct {
    camera: components.Camera,
})) !void {
    const allocator = std.heap.smp_allocator;
    var shapes_2d = std.ArrayList(RenderItem).empty;
    defer shapes_2d.deinit(allocator);
    var shapes_3d = std.ArrayList(RenderItem).empty;
    defer shapes_3d.deinit(allocator);

    while (query_shapes.next()) |q| {
        const shape: *components.shape.Shape = q.shape;
        const item: RenderItem = .{
            .shape = shape,
            .transform = q.transform,
            .color = (q.color orelse &jok.Color.white).*,
        };

        if (shape.is2D()) {
            try shapes_2d.append(allocator, item);
        } else {
            try shapes_3d.append(allocator, item);
        }
    }

    const batch = batcher.get();
    if (shapes_2d.items.len > 0) {
        const rend_2d = batch.begin2d();
        defer batch.end2d();

        for (shapes_2d.items) |item| {
            item.shape.setOrigin(jok.j2d.Vector.new(item.transform.getX(), item.transform.getY()));
            switch (item.shape.*) {
                .Circle => |circle| {
                    try rend_2d.circleFilled(circle, item.color, .{});
                },
                .Rectangle => |rect| {
                    _ = rect;
                },
                .Triangle => |tri| {
                    _ = tri;
                },
                .Ellipse => |ellipse| {
                    _ = ellipse;
                },
                .Line => |line| {
                    _ = line;
                },
                .Point => |point| {
                    _ = point;
                },
                .Ray => |ray| {
                    _ = ray;
                },
                else => unreachable,
            }
        }
    }

    if (shapes_3d.items.len > 0) {
        const rend_3d = batch.begin3d();
        defer batch.end3d();

        if (query_cameras.next()) |q| {
            rend_3d.camera = q.camera.camera;
        }

        for (shapes_3d.items) |item| {
            item.shape.setOrigin(item.transform.getTranslation());
            const triangles = buildTrianglesFromShape(item.shape);

            try rend_3d.tri_rd.renderMesh(
                rend_3d.ctx.getCanvasSize(),
                rend_3d,
                rend_3d.trs,
                rend_3d.camera,
                triangles.indicesSlice(),
                triangles.positionsSlice(),
                triangles.normalsSlice(),
                null,
                null,
                .{
                    .aabb = null,
                    .color = item.color.toColorF(),
                    .cull_faces = false,
                },
            );
        }
    }
}
