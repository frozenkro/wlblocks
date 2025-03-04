const b = @import("binder.zig");
const disp = @import("display.zig");
const io = @import("../io_util.zig");
const std = @import("std");
const wl = @cImport({
    @cInclude("wayland-client.h");
});

pub const RegistryError = error{GetRegistryFailed};

pub const WlRegistry = struct {
    registry: *wl.struct_wl_registry,
    binders: ?[]b.Binder,

    var instance: ?*WlRegistry = null;
    pub const registry_listener: wl.struct_wl_registry_listener = .{ .global = global_registry_handler, .global_remove = global_registry_remove_handler };

    pub fn init(display: disp.WlDisplay) RegistryError!WlRegistry {
        const registry = wl.wl_display_get_registry(display.display) orelse {
            return RegistryError.GetRegistryFailed;
        };

        var wl_registry = WlRegistry{ .registry = registry };
        WlRegistry.instance = &wl_registry;
        return wl_registry;
    }

    pub fn register(self: WlRegistry, bindings: []b.Binding) void {
        self.bindings = bindings;
    }

    pub fn global_registry_handler(_: ?*anyopaque, _: ?*wl.struct_wl_registry, id: u32, interface: [*c]const u8, version: u32) callconv(.C) void {
        const self = instance orelse {
            io.print("global registry handler called before initialization\n");
            return;
        };
        io.print("Received registry event for <{s}>, id: {d}, version: {d}.\n", .{ interface, id, version });

        const intZ: [:0]const u8 = std.mem.span(interface);
        for (self.binders) |binder| {
            if (std.mem.eql(u8, intZ, binder.interface_name)) {
                const bind_opq: *anyopaque = wl.wl_registry_bind(self.registry, id, interface, version) orelse {
                    io.print("Failed to bind '{s}', terminating.\n", .{binder.interface_name});
                    unreachable;
                };

                binder.bind(bind_opq);
                return;
            }
        }
    }

    pub fn global_registry_remove_handler(_: ?*anyopaque, _: ?*wl.struct_wl_registry, id: u32) callconv(.C) void {
        io.print("Received registry remove event for id: {d}", .{id});
    }
};
