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

    pub fn begin2d(self: *Batch) *jok.j2d.Batch {
        return self.tryBegin2d() orelse @panic("failed to begin 2D render batch");
    }

    pub fn tryBegin2d(self: *Batch) ?*jok.j2d.Batch {
        if (self.current3d) |_| {
            @panic("2D used while 3D batch is active");
        }
        if (self.current2d) |b| {
            b.submit();
            self.current2d = null;
            self.reclaim();
        }
        self.current2d = self.pool2d.new(.{}) catch return null;
        return self.current2d;
    }

    pub fn end2d(self: *Batch) void {
        if (self.current3d) |_| {
            @panic("2D used while 3D batch is active");
        }
        if (self.current2d) |b| {
            b.submit();
            self.current2d = null;
        }
    }

    pub fn begin3d(self: *Batch) *jok.j3d.Batch {
        return self.tryBegin3d() orelse @panic("failed to begin 3D render batch");
    }

    pub fn tryBegin3d(self: *Batch) ?*jok.j3d.Batch {
        if (self.current2d) |_| {
            @panic("3D used while 2D batch is active");
        }
        if (self.current3d) |b| {
            b.submit();
            self.current3d = null;
        }
        self.current3d = self.pool3d.new(.{}) catch return null;
        return self.current3d;
    }

    pub fn end3d(self: *Batch) void {
        if (self.current2d) |_| {
            @panic("3D used while 2D batch is active");
        }
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

    pub fn reclaim(self: *Batch) void {
        if (self.current2d) |batch| {
            batch.recycleMemory();
            self.current2d = null;
        }
        if (self.current3d) |batch| {
            batch.recycleMemory();
            self.current3d = null;
        }
    }
};
