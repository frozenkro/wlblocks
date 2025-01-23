const std = @import("std");
const wl = @cImport({
    @cInclude("wayland-client.h");
});

var display: ?*wl.struct_wl_display = null;
var registry: ?*wl.struct_wl_registry = null;
const stdout = std.io.getStdOut().writer();

fn global_registry_handler(_: ?*anyopaque, _: ?*wl.struct_wl_registry, id: u32, interface: [*c]const u8, version: u32) callconv(.C) void {
    stdout.print("Received registry event for <{s}>, id: {d}, version: {d}.\n", .{ interface, id, version }) catch |err| {
        std.debug.print("Error when printing to console: {any}", .{err});
    };
}

fn global_registry_remove_handler(_: ?*anyopaque, _: ?*wl.struct_wl_registry, id: u32) callconv(.C) void {
    stdout.print("Received registry remove event for id: {d}", .{id}) catch |err| {
        std.debug.print("Error when printing to console: {any}", .{err});
    };
}

const registry_listener: wl.struct_wl_registry_listener = .{ .global = global_registry_handler, .global_remove = global_registry_remove_handler };

pub fn main() !void {
    // Connect to the Wayland display
    display = wl.wl_display_connect(null) orelse return error.DisplayConnectFailed;
    defer wl.wl_display_disconnect(display);

    // Get the registry to find available protocols
    registry = wl.wl_display_get_registry(display) orelse return error.GetRegistryFailed;
    _ = wl.wl_registry_add_listener(registry, &registry_listener, null);

    _ = wl.wl_display_dispatch(display);
    _ = wl.wl_display_roundtrip(display);

    // handle protocols
    // - wl_compositor (for creating surfaces)
    // - xdg_wm_base (for window management)
    // - wl_shm (shared memory for software rendering)
}
