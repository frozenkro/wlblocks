const std = @import("std");
const io = @import("io_util.zig");
const wl = @cImport({
    @cInclude("wayland-client.h");
});
const xdg_shell = @cImport({
    @cInclude("xdg-shell.h");
});

var xdg_wm_base: ?*xdg_shell.xdg_wm_base = null; // base of xdg shell protocol
var xdg_surface: ?*xdg_shell.xdg_surface = null; // based on wl_surface
var xdg_toplevel: ?*xdg_shell.xdg_toplevel = null; // an xdg surface role

fn xdg_wm_base_ping_handler(_: ?*anyopaque, wm_base: ?*xdg_shell.xdg_wm_base, serial: u32) callconv(.C) void {
    xdg_shell.xdg_wm_base_pong(wm_base, serial);
}

const xdg_wm_base_listener: xdg_shell.xdg_wm_base_listener = .{ .ping = xdg_wm_base_ping_handler };

fn xdg_surface_configure_handler(_: ?*anyopaque, xs: ?*xdg_shell.xdg_surface, serial: u32) callconv(.C) void {
    xdg_shell.xdg_surface_ack_configure(xs, serial);
}

const xdg_surface_listener: xdg_shell.xdg_surface_listener = .{ .configure = xdg_surface_configure_handler };

fn xdg_toplevel_configure_handler(_: ?*anyopaque, _: ?*xdg_shell.xdg_toplevel, width: i32, height: i32, _: [*c]xdg_shell.wl_array) callconv(.C) void {
    io.print("xdg toplevel configure: {d}x{d}\n", .{ width, height });
}

fn xdg_toplevel_close_handler(_: ?*anyopaque, _: ?*xdg_shell.xdg_toplevel) callconv(.C) void {
    io.print("closing xdg toplevel", .{});
}

const xdg_toplevel_listener: xdg_shell.xdg_toplevel_listener = .{
    .configure = xdg_toplevel_configure_handler,
    .close = xdg_toplevel_close_handler,
};
