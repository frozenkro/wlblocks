const colors = @import("colors.zig");
const std = @import("std");
const pm = @import("pixel_matrix.zig");
const xdg = @import("../wayland/xdg.zig");
const PixelMatrix = pm.PixelMatrix;

pub fn createPaletteMtx(allocator: std.mem.Allocator) pm.PixelMatrixError!PixelMatrix {
    const width = xdg.width - @divFloor(xdg.width, 10);
    const height = xdg.height - @divFloor(xdg.height, 10);
    const mtx = try PixelMatrix.init(allocator, width, height, null);

    const palette = [_]u32{
        colors.COLOR_BLUE,
        colors.COLOR_DARKBLUE,
        colors.COLOR_GREEN,
        colors.COLOR_ORANGE,
        colors.COLOR_PURPLE,
        colors.COLOR_RED,
        colors.COLOR_YELLOW,
    };

    const numColors = palette.len;
    const colorWidth = width / numColors;
    for (mtx.rows) |row| {
        var i: usize = 0;
        for (palette) |color| {
            const slc = row[i .. i + colorWidth];
            @memset(slc, color);
            i += colorWidth;
        }
    }

    return mtx;
}
