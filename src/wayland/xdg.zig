const std = @import("std");
const io = @import("../io_util.zig");
const wl = @cImport({
    @cInclude("wayland-client.h");
});
const xdg_shell = @cImport({
    @cInclude("xdg-shell.h");
});

pub var xdg_wm_base: ?*xdg_shell.xdg_wm_base = null; // base of xdg shell protocol
pub var xdg_surface: ?*xdg_shell.xdg_surface = null; // based on wl_surface
pub var xdg_toplevel: ?*xdg_shell.xdg_toplevel = null; // an xdg surface role

pub var width: u32 = 460;
pub var height: u32 = 380;
pub var resized = false;
pub var unknown_size = true;

fn xdg_wm_base_ping_handler(_: ?*anyopaque, wm_base: ?*xdg_shell.xdg_wm_base, serial: u32) callconv(.C) void {
    xdg_shell.xdg_wm_base_pong(wm_base, serial);
}

pub const xdg_wm_base_listener: xdg_shell.xdg_wm_base_listener = .{ .ping = xdg_wm_base_ping_handler };

fn xdg_surface_configure_handler(_: ?*anyopaque, xs: ?*xdg_shell.xdg_surface, serial: u32) callconv(.C) void {
    xdg_shell.xdg_surface_ack_configure(xs, serial);
}

pub const xdg_surface_listener: xdg_shell.xdg_surface_listener = .{ .configure = xdg_surface_configure_handler };

fn xdg_toplevel_configure_handler(_: ?*anyopaque, _: ?*xdg_shell.xdg_toplevel, new_width: i32, new_height: i32, _: [*c]xdg_shell.wl_array) callconv(.C) void {
    io.print("xdg toplevel configure: {d}x{d}\n", .{ new_width, new_height });
    if (new_width < 0 or new_height < 0) {
        unknown_size = true;
        resized = true;
        return;
    }

    width = @intCast(new_width);
    height = @intCast(new_height);
    resized = true;
}

fn xdg_toplevel_close_handler(_: ?*anyopaque, _: ?*xdg_shell.xdg_toplevel) callconv(.C) void {
    io.print("closing xdg toplevel\n", .{});
}

pub const xdg_toplevel_listener: xdg_shell.xdg_toplevel_listener = .{
    .configure = xdg_toplevel_configure_handler,
    .close = xdg_toplevel_close_handler,
};
