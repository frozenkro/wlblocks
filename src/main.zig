const std = @import("std");
const wc = @import("wayland/client.zig");
const shm = @import("wayland/shm.zig");
const cairo = @import("mtx/examples/cairo.zig");
const colors = @import("mtx/colors.zig");
const palette = @import("mtx/examples/palette.zig");
const patterns = @import("mtx/examples/patterns.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    var wlclient = try wc.WlClient.init(&alloc);
    defer wlclient.deinit();

    // var example_mtx = try patterns.createSolidMatrix(wlclient.window.dimensions(), alloc);
    var example_mtx = try patterns.createGridMatrix(wlclient.window.dimensions(), alloc);
    // var example_mtx = try cairo.createPngMatrix("nyan-cat.png", alloc);
    //var example_mtx = try palette.createPaletteMtx(alloc);
    defer example_mtx.deinit();
    try wlclient.draw(example_mtx);

    while (true) {
        wlclient.clientLoop() catch {
            break;
        };
    }
}
