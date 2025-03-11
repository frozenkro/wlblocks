const std = @import("std");
const cairo = @cImport({
    @cInclude("cairo.h");
});
const io = @import("../io_util.zig");
const pm = @import("pixel_matrix.zig");
const PixelMatrix = pm.PixelMatrix;
const PixelMatrixError = pm.PixelMatrixError;

const CairoError = error{SurfaceStatusError};
const CreatePngMatrixError = CairoError || PixelMatrixError;

pub fn createPngMatrix(file_name: []const u8, allocator: std.mem.Allocator) CreatePngMatrixError!PixelMatrix {
    const surface = cairo.cairo_image_surface_create_from_png(@ptrCast(file_name));
    const status = cairo.cairo_surface_status(surface);
    if (status != cairo.CAIRO_STATUS_SUCCESS) {
        io.print("Cairo status: {d}", .{status});
        return CairoError.SurfaceStatusError;
    }
    defer cairo.cairo_surface_destroy(surface);

    const img_width: usize = @intCast(cairo.cairo_image_surface_get_width(surface));
    const img_height: usize = @intCast(cairo.cairo_image_surface_get_height(surface));
    const img_stride_bytes: usize = @intCast(cairo.cairo_image_surface_get_stride(surface));
    const stride_u32: usize = img_stride_bytes / @sizeOf(u32);

    const img_data_u32: [*]u32 = @ptrCast(@alignCast(cairo.cairo_image_surface_get_data(surface)));

    var buffer = try allocator.alloc(u32, img_width * img_height);
    defer allocator.free(buffer);

    var y: usize = 0;
    while (y < img_height) : (y += 1) {
        const src_row = img_data_u32[y * stride_u32 .. y * stride_u32 + img_width];
        const dst_row = buffer[y * img_width .. (y + 1) * img_width];
        @memcpy(dst_row, src_row);
    }

    const mtx = try PixelMatrix.init(allocator, img_width, img_height, buffer);

    return mtx;
}
