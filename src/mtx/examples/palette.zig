const colors = @import("../colors.zig");
const std = @import("std");
const pm = @import("../pixel_matrix.zig");
const win = @import("../../wayland/window.zig");
const PixelMatrix = pm.PixelMatrix;

const CreatePaletteMtxError = pm.PixelMatrixError || error{WindowNotFound};

pub fn createPaletteMtx(allocator: std.mem.Allocator) CreatePaletteMtxError!PixelMatrix {
    if (win.WlWindow.instance == null) {
        return CreatePaletteMtxError.WindowNotFound;
    }
    const dimensions = win.WlWindow.instance.?.dimensions();
    const width = dimensions.x - @divFloor(dimensions.x, 10);
    const height = dimensions.y - @divFloor(dimensions.y, 10);
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
