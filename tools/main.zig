const std = @import("std");
const cairo = @cImport({
    @cInclude("cairo.h");
});

pub fn main() !void {
    const surface = cairo.cairo_image_surface_create(
        cairo.CAIRO_FORMAT_ARGB32,
        240,
        80,
    );
    defer cairo.cairo_surface_destroy(surface);
    const cr = cairo.cairo_create(surface);
    defer cairo.cairo_destroy(cr);

    std.debug.print("Testing cairo\n", .{});
    cairo.cairo_select_font_face(
        cr,
        "serif",
        cairo.CAIRO_FONT_SLANT_NORMAL,
        cairo.CAIRO_FONT_WEIGHT_BOLD,
    );
    cairo.cairo_set_font_size(cr, 32.0);
    cairo.cairo_set_source_rgb(cr, 0.0, 0.0, 1.0);
    cairo.cairo_move_to(cr, 10.0, 50.0);
    cairo.cairo_show_text(cr, "Hello squirrel");
    _ = cairo.cairo_surface_write_to_png(surface, "hello.png");
}
