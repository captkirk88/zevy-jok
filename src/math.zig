const std = @import("std");
const jok = @import("jok");
const math = jok.vendor.zmath;

/// 2D vector type alias
pub const Vector2 = jok.j2d.Vector;

/// 3D vector type alias
pub const Vector3 = jok.j3d.Vector;

/// 4D vector type alias
pub const Vector4 = math.Vec;

/// Matrix type alias
pub const Matrix = math.Mat;

pub const Transform = struct {
    mat: Matrix,

    pub fn getX(self: Transform) f32 {
        return self.mat[3][0];
    }
    pub fn getY(self: Transform) f32 {
        return self.mat[3][1];
    }

    pub fn getZ(self: Transform) f32 {
        return self.mat[3][2];
    }

    pub fn getTranslation(self: Transform) Vector3 {
        return Vector3{ self.getX(), self.getY(), self.getZ() };
    }

    pub fn identity() Transform {
        return Transform{
            .mat = math.identity(),
        };
    }

    pub fn mul(self: Transform, other: Transform) Transform {
        return Transform{
            .mat = self.mat * other.mat,
        };
    }

    pub fn transformPoint(self: Transform, point: Vector2) Vector2 {
        const p = math.Vec{ point[0], point[1], 0, 1 };
        const result = self.mat * p;
        return Vector2{ result[0], result[1] };
    }

    pub fn transformVector(self: Transform, vec: Vector2) Vector2 {
        const v = math.Vec{ vec[0], vec[1], 0, 0 };
        const result = self.mat * v;
        return Vector2{ result[0], result[1] };
    }

    pub fn translation(translation_vec: Vector2) Transform {
        const xy = translation_vec.data;
        return Transform{
            .mat = math.translation(xy[0], xy[1], 0),
        };
    }

    pub fn rotation(angle_radians: f32) Transform {
        return Transform{
            .mat = math.rotationZ(angle_radians),
        };
    }

    pub fn scale(scale_vec: Vector2) Transform {
        return Transform{
            .mat = math.scaling(scale_vec[0], scale_vec[1], 1),
        };
    }

    pub fn translationRotationScale(translation_vec: Vector2, rotation_radians: f32, scale_vec: Vector2) Transform {
        return Transform{
            .mat = math.translation(translation_vec[0], translation_vec[1], 0) *
                math.rotationZ(rotation_radians) *
                math.scaling(scale_vec[0], scale_vec[1], 1),
        };
    }

    pub fn inverse(self: Transform) Transform {
        return Transform{
            .mat = math.inverse(self.mat),
        };
    }

    pub fn transpose(self: Transform) Transform {
        return Transform{
            .mat = math.transpose(self.mat),
        };
    }

    pub fn copy(self: Transform) Transform {
        return Transform{
            .mat = self.mat,
        };
    }
};
