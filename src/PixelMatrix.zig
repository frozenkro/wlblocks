const std = @import("std");
const Error = std.mem.Allocator.Error;

const PixelMatrixError = error{DataSizeMismatch};

const PixelMatrix = struct {
    width: usize,
    height: usize,
    buffer: []u32,
    rows: [][]u32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize, data: ?[*]u32) Error!PixelMatrix {
        if (data != null and data.len != width * height) {
            return PixelMatrixError.DataSizeMismatch;
        }

        const buffer = try allocator.alloc(u32, width * height);
        const rows = try allocator.alloc([]u32, height);

        var i: usize = 0;
        if (data != null) {
            while (i < data.len) : (i += 1) {
                buffer[i] = data[i];
            }
        }

        i = 0;
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
