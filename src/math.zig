const std = @import("std");
const jok = @import("jok");
const math = jok.vendor.zmath;

pub const Vector2 = @Vector(2, f32);
pub const Vector2i = @Vector(2, i32);

pub const Vector3 = @Vector(3, f32);
pub const Vector3i = @Vector(3, i32);

pub const Vector4 = math.Vec;
pub const Vector4i = @Vector(4, i32);
