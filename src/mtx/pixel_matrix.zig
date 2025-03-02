const std = @import("std");
const Error = std.mem.Allocator.Error;

pub const PixelMatrixError = error{DataSizeMismatch} || std.mem.Allocator.Error;

pub const PixelMatrix = struct {
    width: usize,
    height: usize,
    buffer: []u32,
    rows: [][]u32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize, data: ?[]u32) PixelMatrixError!PixelMatrix {
        if (data != null and data.?.len != height * width) {
            return PixelMatrixError.DataSizeMismatch;
        }

        const buffer = try allocator.alloc(u32, height * width);
        const rows = try allocator.alloc([]u32, height);

        if (data != null) {
            @memcpy(buffer, data.?);
        }

        var i: usize = 0;
        while (i < height) : (i += 1) {
            rows[i] = buffer[i * width .. (i + 1) * width];
        }

        return .{
            .width = width,
            .height = height,
            .buffer = buffer,
            .rows = rows,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *PixelMatrix) void {
        self.allocator.free(self.rows);
        self.allocator.free(self.buffer);
    }
};
