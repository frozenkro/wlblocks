const std = @import("std");
const Error = std.mem.Allocator.Error;

pub const MatrixError = error{DataSizeMismatch} || std.mem.Allocator.Error;
pub const PixelMatrix = Matrix(u32);
pub const CollisionMatrix = Matrix(bool);

pub fn Matrix(comptime T: type) type {
    return struct {
        width: usize,
        height: usize,
        buffer: []T,
        rows: [][]T,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, width: usize, height: usize, data: ?[]T) MatrixError!Matrix(T) {
            if (data != null and data.?.len != height * width) {
                return MatrixError.DataSizeMismatch;
            }

            const buffer = try allocator.alloc(T, height * width);
            const rows = try allocator.alloc([]T, height);

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

        pub fn deinit(self: *Matrix(T)) void {
            self.allocator.free(self.rows);
            self.allocator.free(self.buffer);
        }

        // pub fn MoveMatrix(self: *Matrix(T)) void {

        // }
    };
}

pub fn CollisionMatrixFromPixelMatrix(pm: PixelMatrix) MatrixError!CollisionMatrix {
    var bools = try pm.allocator.alloc(bool, pm.buffer.len);
    defer pm.allocator.free(bools);

    for (pm.buffer, 0..) |pixel, i| {
        bools[i] = pixel == 0;
    }

    return try CollisionMatrix.init(pm.allocator, pm.width, pm.height, bools);
}
