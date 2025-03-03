const disp = @import("display.zig");
const io = @import("../io_util.zig");
const std = @import("std");
const wl = @cImport({
    @cInclude("wayland-client.h");
});

pub const RegistryError = error{GetRegistryFailed};

pub fn Registration(comptime T: type) type {
    return struct {
        interface_name: []const u8,
        interface: *wl.struct_wl_interface,
        version: u32,
        bind_set_callback: *const fn (instance: T, binding: *anyopaque) void,
        callback_inst: T,
    };
}

pub const WlRegistry = struct {
    registry: *wl.struct_wl_registry,
    registrations: []Registration,

    var instance: ?*WlRegistry = null;
    pub const registry_listener: wl.struct_wl_registry_listener = .{ .global = global_registry_handler, .global_remove = global_registry_remove_handler };

    pub fn init(display: disp.WlDisplay, registrations: []Registration) RegistryError!WlRegistry {
        const registry = wl.wl_display_get_registry(display.display) orelse return RegistryError.GetRegistryFailed;

        var wl_registry = WlRegistry{
            .registry = registry,
            .registrations = registrations,
        };
        WlRegistry.instance = &wl_registry;
        return wl_registry;
    }

    pub fn global_registry_handler(_: ?*anyopaque, _: ?*wl.struct_wl_registry, id: u32, interface: [*c]const u8, version: u32) callconv(.C) void {
        const self = instance orelse {
            io.print("global registry handler called before initialization\n");
            return;
        };
        io.print("Received registry event for <{s}>, id: {d}, version: {d}.\n", .{ interface, id, version });

        const intZ: [:0]const u8 = std.mem.span(interface);
        for (self.registrations) |registration| {
            if (std.mem.eql(u8, intZ, registration.interface_name)) {
                const bind_opq: *anyopaque = wl.wl_registry_bind(self.registry, id, interface, version) orelse {
                    io.print("Failed to bind '{s}', terminating.\n", .{registration.interface_name});
                    unreachable;
                };

                registration.bind_set_callback(bind_opq);
                return;
            }
        }

        // if (std.mem.eql(u8, intZ, "wl_compositor")) {
        //     const compositor_opq: ?*anyopaque = wl.wl_registry_bind(registry, id, &wl.wl_compositor_interface, 4) orelse {
        //         io.print("Failed to bind wl_compositor, terminating.\n", .{});
        //         unreachable;
        //     };
        //     compositor = @ptrCast(compositor_opq);
        // } else if (std.mem.eql(u8, intZ, "xdg_wm_base")) {
        //     const xdg_base_opq: ?*anyopaque = xdg_shell.wl_registry_bind(@ptrCast(registry), id, &xdg_shell.xdg_wm_base_interface, 1) orelse {
        //         io.print("Failed to bind xdg_wm_base, terminating.\n", .{});
        //         unreachable;
        //     };
        //     xdg.xdg_wm_base = @ptrCast(xdg_base_opq);
        // } else if (std.mem.eql(u8, intZ, "wl_shm")) {
        //     const shm_opq: *anyopaque = wl.wl_registry_bind(registry, id, &wl.wl_shm_interface, 1) orelse {
        //         io.print("Failed to bind wl_shm, terminating.\n", .{});
        //         unreachable;
        //     };
        //     shm.shm = @ptrCast(shm_opq);
        // }
    }

    pub fn global_registry_remove_handler(_: ?*anyopaque, _: ?*wl.struct_wl_registry, id: u32) callconv(.C) void {
        io.print("Received registry remove event for id: {d}", .{id});
    }
};
