const colors = @import("../colors.zig");
const dim = @import("../../wayland/models/dimensions.zig");
const mtx = @import("../matrix.zig");
const std = @import("std");

pub fn createSolidMatrix(dimensions: dim.Dimensions, allocator: std.mem.Allocator) mtx.MatrixError!mtx.PixelMatrix {
    const buffer = try allocator.alloc(u32, dimensions.x * dimensions.y);
    defer allocator.free(buffer);
    @memset(buffer, colors.COLOR_YELLOW);

    const solid_mtx = try mtx.PixelMatrix.init(allocator, dimensions.x, dimensions.y, buffer);
    return solid_mtx;
}

pub fn createGridMatrix(dimensions: dim.Dimensions, allocator: std.mem.Allocator) mtx.MatrixError!mtx.PixelMatrix {
    const grid_mtx = try mtx.PixelMatrix.init(allocator, dimensions.x, dimensions.y, null);

    const grid_size: usize = 20;
    const c1: u32 = colors.COLOR_GREEN;
    const c2: u32 = colors.COLOR_ORANGE;
    var swap_ctr: usize = 0;
    var stag_ctr: usize = 0;
    var swap = false;
    var stagger = false;
    for (grid_mtx.rows) |row| {
        if (stag_ctr == grid_size) {
            stag_ctr = 0;
            stagger = !stagger;
        } else {
            stag_ctr += 1;
        }
        swap_ctr = 0;

        for (row, 0..) |_, i| {
            if (swap_ctr == grid_size) {
                swap_ctr = 0;
                swap = !swap;
            } else {
                swap_ctr += 1;
            }

            row[i] = if (stagger == swap) c1 else c2;
        }
    }
    return grid_mtx;
}
