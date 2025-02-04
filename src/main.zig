const std = @import("std");
const wl = @cImport({
    @cInclude("wayland-client.h");
});
const xdg_shell = @cImport({
    @cInclude("xdg-shell.h");
});

const stdout = std.io.getStdOut().writer();

var display: ?*wl.struct_wl_display = null;
var registry: ?*wl.struct_wl_registry = null;
var compositor: ?*wl.struct_wl_compositor = null;
var surface: ?*wl.struct_wl_surface = null;
var shm: ?*wl.wl_shm = null;
var buffer: ?*wl.wl_buffer = null;
var shm_data: ?*anyopaque = null;

var xdg_wm_base: ?*xdg_shell.xdg_wm_base = null; // base of xdg shell protocol
var xdg_surface: ?*xdg_shell.xdg_surface = null; // based on wl_surface
var xdg_toplevel: ?*xdg_shell.xdg_toplevel = null; // an xdg surface role

var c_int_res: c_int = 0;

fn print_err(err: anyerror) void {
    std.debug.print("Error when printing to console: {any}\n", .{err});
}

fn global_registry_handler(_: ?*anyopaque, _: ?*wl.struct_wl_registry, id: u32, interface: [*c]const u8, version: u32) callconv(.C) void {
    stdout.print("Received registry event for <{s}>, id: {d}, version: {d}.\n", .{ interface, id, version }) catch |err| {
        print_err(err);
    };

    const intZ: [:0]const u8 = std.mem.span(interface);
    if (std.mem.eql(u8, intZ, "wl_compositor")) {
        const compositor_opq: ?*anyopaque = wl.wl_registry_bind(registry, id, &wl.wl_compositor_interface, 4);
        compositor = @ptrCast(compositor_opq);
    } else if (std.mem.eql(u8, intZ, "xdg_wm_base")) {
        const xdg_base_opq: ?*anyopaque = xdg_shell.wl_registry_bind(@ptrCast(registry), id, &xdg_shell.xdg_wm_base_interface, 1);
        xdg_wm_base = @ptrCast(xdg_base_opq);
    } else if (std.mem.eql(u8, intZ, "wl_shm")) {
        shm = wl.wl_registry_bind(registry, id, &wl.wl_shm_interface, 1);
        wl.wl_shm_add_listener(shm, &wl.wl_shm_listener, null);
    }
}

fn global_registry_remove_handler(_: ?*anyopaque, _: ?*wl.struct_wl_registry, id: u32) callconv(.C) void {
    stdout.print("Received registry remove event for id: {d}", .{id}) catch |err| {
        print_err(err);
    };
}

const registry_listener: wl.struct_wl_registry_listener = .{ .global = global_registry_handler, .global_remove = global_registry_remove_handler };

fn xdg_wm_base_ping_handler(_: ?*anyopaque, wm_base: ?*xdg_shell.xdg_wm_base, serial: u32) callconv(.C) void {
    xdg_shell.xdg_wm_base_pong(wm_base, serial);
}

const xdg_wm_base_listener: xdg_shell.xdg_wm_base_listener = .{ .ping = xdg_wm_base_ping_handler };

fn xdg_surface_configure_handler(_: ?*anyopaque, xs: ?*xdg_shell.xdg_surface, serial: u32) callconv(.C) void {
    xdg_shell.xdg_surface_ack_configure(xs, serial);
}

const xdg_surface_listener: xdg_shell.xdg_surface_listener = .{ .configure = xdg_surface_configure_handler };

fn xdg_toplevel_configure_handler(_: ?*anyopaque, _: ?*xdg_shell.xdg_toplevel, width: i32, height: i32, _: [*c]xdg_shell.wl_array) callconv(.C) void {
    stdout.print("xdg toplevel configure: {d}x{d}\n", .{ width, height }) catch |err| {
        print_err(err);
    };
}

fn xdg_toplevel_close_handler(_: ?*anyopaque, _: ?*xdg_shell.xdg_toplevel) callconv(.C) void {
    stdout.print("closing xdg toplevel", .{}) catch |err| {
        print_err(err);
    };
}

const xdg_toplevel_listener: xdg_shell.xdg_toplevel_listener = .{
    .configure = xdg_toplevel_configure_handler,
    .close = xdg_toplevel_close_handler,
};

fn shm_format_handler(_: ?*anyopaque, _: ?*wl.wl_shm, format: u32) callconv(.C) void {
    stdout.print("Format {d}\n", .{format}) catch |err| print_err(err);
}

const shm_listener: wl.wl_shm_listener = .{
    .format = shm_format_handler,
};

pub fn main() !void {
    // Connect to the Wayland display
    display = wl.wl_display_connect(null) orelse return error.DisplayConnectFailed;
    defer wl.wl_display_disconnect(display);

    // Get the registry to find available protocols
    registry = wl.wl_display_get_registry(display) orelse return error.GetRegistryFailed;
    const add_listener_result = wl.wl_registry_add_listener(registry, &registry_listener, null);
    if (add_listener_result != 0) {
        return error.AddListenerFailed;
    }

    const dispatch_result = wl.wl_display_dispatch(display);
    if (dispatch_result == -1) {
        return error.DispatchFailed;
    }

    const roundtrip_result = wl.wl_display_roundtrip(display);
    if (roundtrip_result == -1) {
        return error.RoundtripFailed;
    }

    if (compositor == null) {
        return error.CompositorConnectFailed;
    }

    surface = wl.wl_compositor_create_surface(compositor) orelse return error.SurfaceCreationFailed;
    defer wl.wl_surface_destroy(surface);
    try stdout.print("Created a surface", .{});

    // add listener to wm base
    c_int_res = xdg_shell.xdg_wm_base_add_listener(xdg_wm_base, &xdg_wm_base_listener, null);
    if (c_int_res != 0) {
        return error.AddListenerFailed;
    }

    // create xdg surface
    xdg_surface = xdg_shell.xdg_wm_base_get_xdg_surface(xdg_wm_base, @ptrCast(surface));
    c_int_res = xdg_shell.xdg_surface_add_listener(xdg_surface, &xdg_surface_listener, null);
    if (c_int_res != 0) {
        return error.AddListenerFailed;
    }

    // set toplevel role for xdg surface
    xdg_toplevel = xdg_shell.xdg_surface_get_toplevel(xdg_surface);
    c_int_res = xdg_shell.xdg_toplevel_add_listener(xdg_toplevel, &xdg_toplevel_listener, null);
    if (c_int_res != 0) {
        return error.AddListenerFailed;
    }

    wl.wl_surface_commit(surface);

    while (true) {}

    // to do
    // - wl_shm (shared memory for software rendering)
}
