const std = @import("std");
const wlclient = @import("wayland/client.zig");
const shm = @import("wayland/shm.zig");
const xdg = @import("wayland/xdg.zig");
const cairo = @import("mtx/cairo.zig");
const colors = @import("mtx/colors.zig");
const palette = @import("mtx/palette.zig");

const ColorSwapError = error{UnsupportedColor};

fn swapColor(color: u32) ColorSwapError!u32 {
    if (color == colors.COLOR_BLUE) {
        return colors.COLOR_BLACK;
    } else if (color == colors.COLOR_BLACK) {
        return colors.COLOR_BLUE;
    }
    return error.UnsupportedColor;
}

fn draw_solid() void {
    var data: [*]u32 = @ptrCast(@alignCast(shm.shm_data));

    var i: u32 = 0;
    var y: u32 = 0;
    while (y < xdg.height) : (y += 1) {
        var x: u32 = 0;
        while (x < xdg.width) : (x += 1) {
            data[i] = colors.COLOR_BLUE;
            i += 1;
        }
    }
}

fn draw_grid() ColorSwapError!void {
    var row_start_color: u32 = colors.COLOR_BLACK;
    var color: u32 = row_start_color;

    var i: u32 = 0;
    var y: u32 = 0;
    while (y < xdg.height) : (y += 1) {
        if (y % 10 == 0) {
            row_start_color = try swapColor(row_start_color);
        }
        color = row_start_color;

        var x: u32 = 0;
        while (x < xdg.width) : (x += 1) {
            //data[i] = 0xde000000;
            if (x % 10 == 0) {
                color = try swapColor(color);
            }
            shm.shm_data[i] = color;
            i += 1;
        }
    }
}

pub fn main() !void {
    try wlclient.init();
    defer wlclient.deinit();

    //try draw_grid();
    //draw_solid();
    //try cairo.drawPng();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();
    // var cat_map = try cairo.createPngMatrix("nyan-cat.png", alloc);
    // defer cat_map.deinit();
    // shm.draw(cat_map);
    var palette_map = try palette.createPaletteMtx(alloc);
    defer palette_map.deinit();
    shm.draw(palette_map);

    while (true) {
        wlclient.clientLoop() catch {
            break;
        };
    }
}
