const std = @import("std");
const jok = @import("jok");

pub const BatchType = enum {
    @"2D",
    @"3D",
};

pub const BeginOptions = struct {
    @"2D": jok.j2d.BatchOption = .{},
    @"3D": jok.j3d.BatchOption = .{},
};

pub fn BatchPtr(comptime kind: BatchType) type {
    return switch (kind) {
        .@"2D" => *jok.j2d.Batch,
        .@"3D" => *jok.j3d.Batch,
    };
}

pub const Batch = struct {
    context: jok.Context,
    pool2d: jok.j2d.BatchPool(32, false),
    pool3d: jok.j3d.BatchPool(32, false),
    current2d: ?*jok.j2d.Batch = null,
    current3d: ?*jok.j3d.Batch = null,

    pub fn new(context: jok.Context) Batch {
        return init(context) catch @panic("failed to initialize render batch");
    }

    pub fn init(context: jok.Context) !Batch {
        return .{
            .context = context,
            .pool2d = try jok.j2d.BatchPool(32, false).init(context),
            .pool3d = try jok.j3d.BatchPool(32, false).init(context),
        };
    }

    pub fn deinit(self: *Batch) void {
        self.abort();
        self.pool2d.deinit();
        self.pool3d.deinit();
    }

    pub fn begin2d(self: *Batch) void {
        self.tryBegin2d() catch @panic("failed to begin 2D render batch");
    }

    pub fn tryBegin2d(self: *Batch) !void {
        if (self.current2d) |b| {
            b.submit();
            self.current2d = null;
        }
        if (self.current3d) |b| {
            b.abort();
            self.current3d = null;
        }
        self.current2d = try self.pool2d.new(.{});
    }

    pub fn end2d(self: *Batch) void {
        if (self.current2d) |b| {
            b.submit();
            self.current2d = null;
        }
    }

    pub fn begin3d(self: *Batch) void {
        self.tryBegin3d() catch @panic("failed to begin 3D render batch");
    }

    pub fn tryBegin3d(self: *Batch) !void {
        if (self.current3d) |b| {
            b.submit();
            self.current3d = null;
        }
        if (self.current2d) |b| {
            b.abort();
            self.current2d = null;
        }
        self.current3d = try self.pool3d.new(.{});
    }
    pub fn end3d(self: *Batch) void {
        if (self.current3d) |b| {
            b.submit();
            self.current3d = null;
        }
    }

    pub fn submit(self: *Batch) void {
        self.end();
    }

    pub fn submitWithoutReclaim(self: *Batch) void {
        if (self.current2d) |batch| batch.submitWithoutReclaim();
        if (self.current3d) |batch| batch.submitWithoutReclaim();
    }

    pub fn abort(self: *Batch) void {
        if (self.current2d) |batch| {
            batch.abort();
            self.current2d = null;
        }
        if (self.current3d) |batch| {
            batch.abort();
            self.current3d = null;
        }
    }

    pub fn recycleMemory(self: *Batch) void {
        self.pool2d.recycleMemory();
        self.pool3d.recycleMemory();
    }

    /// Returns the currently active batch of the given type. Panics if the batch of that type
    /// has not been begun via `begin2d` / `begin3d`.
    pub fn get(self: *Batch, comptime kind: BatchType) BatchPtr(kind) {
        return switch (kind) {
            .@"2D" => self.current2d orelse @panic("Batch.begin() must be called before getting the 2D batch"),
            .@"3D" => self.current3d orelse @panic("Batch.begin() must be called before getting the 3D batch"),
        };
    }
};
