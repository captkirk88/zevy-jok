const std = @import("std");
const jok = @import("jok");
const math = jok.vendor.zmath;

pub const zmath = math;

pub const pi = std.math.pi;

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

    pub fn random() Transform {
        var threaded: std.Io.Threaded = undefined;
        const io = threaded.io();
        const clock = std.Io.Clock.now(.real, io);
        const seed: u64 = @intCast(clock.nanoseconds);
        var rng = std.Random.DefaultPrng.init(seed);
        const trans = Vector3.new(
            rng.random().float(f32) * 200 - 100,
            rng.random().float(f32) * 200 - 100,
            rng.random().float(f32) * 200 - 100,
        );
        const rot = Vector3.new(
            rng.random().float(f32) * pi * 2,
            rng.random().float(f32) * pi * 2,
            rng.random().float(f32) * pi * 2,
        );
        const scl = Vector3.new(
            rng.random().float(f32) * 2 + 0.5,
            rng.random().float(f32) * 2 + 0.5,
            rng.random().float(f32) * 2 + 0.5,
        );
        const translation_mat = math.translation(trans.x(), trans.y(), trans.z());
        const rotation_x = math.rotationX(rot.x());
        const rotation_y = math.rotationY(rot.y());
        const rotation_z = math.rotationZ(rot.z());
        const scale_mat = math.scaling(scl.x(), scl.y(), scl.z());

        return Transform{
            .mat = math.mul(
                math.mul(
                    math.mul(math.mul(translation_mat, rotation_x), rotation_y),
                    rotation_z,
                ),
                scale_mat,
            ),
        };
    }

    pub fn getX(self: *const Transform) f32 {
        return self.mat[3][0];
    }
    pub fn getY(self: *const Transform) f32 {
        return self.mat[3][1];
    }

    pub fn getZ(self: *const Transform) f32 {
        return self.mat[3][2];
    }

    pub fn getTranslation(self: *const Transform) Vector3 {
        return .new(self.getX(), self.getY(), self.getZ());
    }

    pub fn identity() Transform {
        return Transform{
            .mat = math.identity(),
        };
    }

    pub fn mul(self: *const Transform, other: Transform) Transform {
        return Transform{
            .mat = math.mul(self.mat, other.mat),
        };
    }

    /// Creates a translation transform from a 2D vector. The Z component is set to 0.
    pub fn translation(translation_vec: Vector2) Transform {
        const xy = translation_vec.data;
        return Transform{
            .mat = math.translation(xy[0], xy[1], 0),
        };
    }

    /// Creates a rotation transform from an angle in radians. The rotation is applied around the Z axis.
    pub fn rotation(angle_radians: f32) Transform {
        return Transform{
            .mat = math.rotationZ(angle_radians),
        };
    }

    pub fn rotationX(angle_radians: f32) Transform {
        return Transform{
            .mat = math.rotationX(angle_radians),
        };
    }

    pub fn rotationY(angle_radians: f32) Transform {
        return Transform{
            .mat = math.rotationY(angle_radians),
        };
    }

    /// Creates a scaling transform from a 2D vector. The Z component is set to 1.
    pub fn scale(scale_vec: Vector2) Transform {
        return Transform{
            .mat = math.scaling(scale_vec[0], scale_vec[1], 1),
        };
    }

    /// Creates a scaling transform from a 3D vector.
    pub fn scaleZ(scale_vec: Vector3) Transform {
        return Transform{
            .mat = math.scaling(scale_vec[0], scale_vec[1], scale_vec[2]),
        };
    }

    /// Creates a transform from translation, rotation, and scale components. The rotation is applied around the Z axis.
    pub fn translationRotationScale(translation_vec: Vector2, rotation_radians: f32, scale_vec: Vector2) Transform {
        const translation_mat = math.translation(translation_vec[0], translation_vec[1], 0);
        const rotation_mat = math.rotationZ(rotation_radians);
        const scale_mat = math.scaling(scale_vec[0], scale_vec[1], 1);

        return Transform{
            .mat = math.mul(math.mul(translation_mat, rotation_mat), scale_mat),
        };
    }

    pub fn inverse(self: *const Transform) Transform {
        return Transform{
            .mat = math.inverse(self.mat),
        };
    }

    pub fn transpose(self: *const Transform) Transform {
        return Transform{
            .mat = math.transpose(self.mat),
        };
    }

    /// Translates the transform by the given translation vector in 2D space. The translation is applied after the existing transform.
    pub fn translate(self: *Transform, translation_vec: Vector2) *Transform {
        const new = self.mul(Transform.translation(translation_vec)).mat;
        self.mat = new;
        return self;
    }

    /// Translates the transform by the given translation vector in 3D space. The translation is applied after the existing transform.
    pub fn translateZ(self: *Transform, translation_vec: Vector3) *Transform {
        const new = self.mul(Transform{
            .mat = math.translation(translation_vec[0], translation_vec[1], translation_vec[2]),
        }).mat;
        self.mat = new;
        return self;
    }

    /// Copy the transform.
    pub fn copy(self: *const Transform) Transform {
        return Transform{
            .mat = self.mat,
        };
    }
};

pub fn radians(degrees_: f32) f32 {
    return degrees_ * (pi / 180.0);
}

pub fn degrees(radians_: f32) f32 {
    return radians_ * (180.0 / pi);
}

pub fn degToRad(degrees_: f32) f32 {
    return radians(degrees_);
}
