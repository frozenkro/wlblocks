const std = @import("std");
const cairo = @cImport({
    @cInclude("cairo.h");
});
const io = @import("io_util.zig");
const shm = @import("shm.zig");
const xdg = @import("xdg.zig");
const PixelMatrix = @import("PixelMatrix.zig").PixelMatrix;

const CairoError = error{SurfaceStatusError};
const CreatePngMatrixError = CairoError || std.mem.Allocator.Error;

pub fn drawPng() !void {
    const surface = cairo.cairo_image_surface_create_from_png("nyan-cat.png");
    const status = cairo.cairo_surface_status(surface);
    if (status != cairo.CAIRO_STATUS_SUCCESS) {
        io.print("Cairo status: {d}", .{status});
        return CairoError.SurfaceStatusError;
    }
    defer cairo.cairo_surface_destroy(surface);

    const img_data: [*]u32 = @ptrCast(@alignCast(cairo.cairo_image_surface_get_data(surface)));
    const img_width: u32 = @intCast(cairo.cairo_image_surface_get_width(surface));
    const img_height: u32 = @intCast(cairo.cairo_image_surface_get_height(surface));

    var i: usize = 0;
    var img_idx: u32 = 0;
    while (i < img_height) : (i += 1) {
        var j: usize = 0;
        const window_offset: usize = i * xdg.xdg_width;
        while (j < img_width) : (j += 1) {
            shm.shm_data[@intCast(window_offset + j)] = img_data[img_idx];
            img_idx += 1;
        }
    }
}

pub fn createPngMatrix(file_name: []const u8, allocator: std.mem.Allocator) CreatePngMatrixError!PixelMatrix {
    const surface = cairo.cairo_image_surface_create_from_png(@ptrCast(file_name));
    const status = cairo.cairo_surface_status(surface);
    if (status != cairo.CAIRO_STATUS_SUCCESS) {
        io.print("Cairo status: {d}", .{status});
        return CairoError.SurfaceStatusError;
    }
    defer cairo.cairo_surface_destroy(surface);

    const img_data: [*]u32 = @ptrCast(@alignCast(cairo.cairo_image_surface_get_data(surface)));
    const img_width: u32 = @intCast(cairo.cairo_image_surface_get_width(surface));
    const img_height: u32 = @intCast(cairo.cairo_image_surface_get_height(surface));

    const mtx = try PixelMatrix.init(allocator, img_width, img_height, img_data);

    return mtx;
}
