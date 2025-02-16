const std = @import("std");
const io = @import("io_util.zig");
const xdg = @import("xdg.zig");
const shm = @import("shm.zig");
const wl = @cImport({
    @cInclude("wayland-client.h");
});
const xdg_shell = @cImport({
    @cInclude("xdg-shell.h");
});

const AddListenerError = error{AddListenerFailed};

var display: ?*wl.struct_wl_display = null;
var registry: ?*wl.struct_wl_registry = null;
var compositor: ?*wl.struct_wl_compositor = null;
var surface: ?*wl.struct_wl_surface = null;
var buffer: ?*wl.wl_buffer = null;

var c_int_res: c_int = 0;

fn global_registry_handler(_: ?*anyopaque, _: ?*wl.struct_wl_registry, id: u32, interface: [*c]const u8, version: u32) callconv(.C) void {
    io.print("Received registry event for <{s}>, id: {d}, version: {d}.\n", .{ interface, id, version });

    const intZ: [:0]const u8 = std.mem.span(interface);
    if (std.mem.eql(u8, intZ, "wl_compositor")) {
        const compositor_opq: ?*anyopaque = wl.wl_registry_bind(registry, id, &wl.wl_compositor_interface, 4) orelse {
            io.print("Failed to bind wl_compositor, terminating.\n", .{});
            unreachable;
        };
        compositor = @ptrCast(compositor_opq);
    } else if (std.mem.eql(u8, intZ, "xdg_wm_base")) {
        const xdg_base_opq: ?*anyopaque = xdg_shell.wl_registry_bind(@ptrCast(registry), id, &xdg_shell.xdg_wm_base_interface, 1) orelse {
            io.print("Failed to bind xdg_wm_base, terminating.\n", .{});
            unreachable;
        };
        xdg.xdg_wm_base = @ptrCast(xdg_base_opq);
    } else if (std.mem.eql(u8, intZ, "wl_shm")) {
        const shm_opq: *anyopaque = wl.wl_registry_bind(registry, id, &wl.wl_shm_interface, 1) orelse {
            io.print("Failed to bind wl_shm, terminating.\n", .{});
            unreachable;
        };
        shm.shm = @ptrCast(shm_opq);
    }
}

fn global_registry_remove_handler(_: ?*anyopaque, _: ?*wl.struct_wl_registry, id: u32) callconv(.C) void {
    io.print("Received registry remove event for id: {d}", .{id});
}

const registry_listener: wl.struct_wl_registry_listener = .{ .global = global_registry_handler, .global_remove = global_registry_remove_handler };

fn shm_format_handler(_: ?*anyopaque, _: ?*wl.wl_shm, format: u32) callconv(.C) void {
    io.print("Format {d}\n", .{format});
}

const shm_listener: wl.wl_shm_listener = .{
    .format = shm_format_handler,
};

fn add_listeners() AddListenerError!void {
    // add listener to wm base
    c_int_res = xdg_shell.xdg_wm_base_add_listener(xdg.xdg_wm_base, &xdg.xdg_wm_base_listener, null);
    if (c_int_res != 0) {
        return error.AddListenerFailed;
    }

    // create xdg surface
    xdg.xdg_surface = xdg_shell.xdg_wm_base_get_xdg_surface(xdg.xdg_wm_base, @ptrCast(surface));
    c_int_res = xdg_shell.xdg_surface_add_listener(xdg.xdg_surface, &xdg.xdg_surface_listener, null);
    if (c_int_res != 0) {
        return error.AddListenerFailed;
    }

    // set toplevel role for xdg surface
    xdg.xdg_toplevel = xdg_shell.xdg_surface_get_toplevel(xdg.xdg_surface);
    c_int_res = xdg_shell.xdg_toplevel_add_listener(xdg.xdg_toplevel, &xdg.xdg_toplevel_listener, null);
    if (c_int_res != 0) {
        return error.AddListenerFailed;
    }

    c_int_res = wl.wl_shm_add_listener(shm.shm, &shm_listener, null);
    if (c_int_res != 0) {
        return error.AddListenerFailed;
    }
}

fn draw(color: u32) void {
    var data: [*]u32 = @ptrCast(@alignCast(shm.shm_data));
    const pxlct = xdg.width * xdg.height;
    var i: u32 = 0;
    while (i < pxlct) : (i += 1) {
        //data[i] = 0xde000000;
        data[i] = color;
    }
}

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

    var roundtrip_result = wl.wl_display_roundtrip(display);
    if (roundtrip_result == -1) {
        return error.RoundtripFailed;
    }

    if (compositor == null) {
        return error.CompositorConnectFailed;
    }

    surface = wl.wl_compositor_create_surface(compositor) orelse return error.SurfaceCreationFailed;
    defer wl.wl_surface_destroy(surface);
    io.print("Created a surface\n", .{});

    try add_listeners();

    wl.wl_surface_commit(surface);
    roundtrip_result = wl.wl_display_roundtrip(display);
    if (roundtrip_result == -1) {
        return error.RoundtripFailed;
    }
    buffer = try shm.create_buffer(xdg.width, xdg.height);

    wl.wl_surface_attach(surface, buffer, 0, 0);
    wl.wl_surface_commit(surface);

    const color = 0xde0000ff;
    draw(color);

    while (wl.wl_display_dispatch(display) >= 0) {
        if (xdg.resized) {
            // buffer = try shm.create_buffer(xdg.width, xdg.height);
            // wl.wl_surface_attach(surface, buffer, 0, 0);
            // wl.wl_surface_commit(surface);

            // draw(color);
        }
    }

    io.print("executing deferred functions", .{});
}
