const jok = @import("jok");

pub const BatchType = enum {
    @"2D",
    @"3D",
    Compute,
};

pub fn Batch(comptime T: BatchType) type {
    return struct {
        const Self = @This();
        pub const Type = T;
    };
}
