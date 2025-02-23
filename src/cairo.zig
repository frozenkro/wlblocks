const std = @import("std");
const cairo = @cImport({
    @cInclude("cairo.h");
});
const io = @import("io_util.zig");
const shm = @import("shm.zig");
const xdg = @import("xdg.zig");

const CairoError = error{SurfaceStatusError};

pub fn drawPng() !void {
    const surface = cairo.cairo_image_surface_create_from_png("nyan-cat.png");
    const status = cairo.cairo_surface_status(surface);
    if (status != cairo.CAIRO_STATUS_SUCCESS) {
        io.print("Cairo status: {d}", .{status});
        return CairoError.SurfaceStatusError;
    }
    defer cairo.cairo_surface_destroy(surface);

    const img_data: [*]u32 = @ptrCast(@alignCast(cairo.cairo_image_surface_get_data(surface)));
    const img_width: i32 = @intCast(cairo.cairo_image_surface_get_width(surface));
    const img_height: i32 = @intCast(cairo.cairo_image_surface_get_height(surface));
    const xdg_width: i32 = @intCast(xdg.width);

    var i: i32 = 0;
    var img_idx: u32 = 0;
    while (i < img_height) : (i += 1) {
        var j: i32 = 0;
        const window_offset: i32 = @intCast(i * xdg_width);
        while (j < img_width) : (j += 1) {
            shm.shm_data[@intCast(window_offset + j)] = img_data[img_idx];
            img_idx += 1;
        }
    }
}
