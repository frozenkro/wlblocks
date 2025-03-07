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
    binders: ?[*]const b.Binder = null,
    binders_len: usize = 0,

    var instance: ?*WlRegistry = null;
    pub const registry_listener: wl.struct_wl_registry_listener = .{ .global = globalRegistryHandler, .global_remove = globalRegistryRemoveHandler };

    pub fn init(display: disp.WlDisplay) RegistryError!WlRegistry {
        const registry = wl.wl_display_get_registry(display.display) orelse {
            return RegistryError.GetRegistryFailed;
        };

        var wl_registry = WlRegistry{
            .registry = registry,
        };
        WlRegistry.instance = &wl_registry;
        return wl_registry;
    }

    pub fn register(self: *WlRegistry, binders: [*]const b.Binder, binders_len: usize) void {
        self.binders = binders;
        self.binders_len = binders_len;
    }

    pub fn globalRegistryHandler(_: ?*anyopaque, _: ?*wl.struct_wl_registry, id: u32, interface: [*c]const u8, version: u32) callconv(.C) void {
        const self: *WlRegistry = WlRegistry.instance orelse {
            io.print("global registry handler called before initialization of registry\n", .{});
            return;
        };
        const binders: [*]const b.Binder = self.binders orelse {
            io.print("global registry handler called before bindings configured\n", .{});
            return;
        };

        io.print("Received registry event for <{s}>, id: {d}, version: {d}.\n", .{ interface, id, version });

        const intZ: [:0]const u8 = std.mem.span(interface);

        var i: usize = 0;
        while (i < self.binders_len) : (i += 1) {
            const binder = binders[i];
            if (std.mem.eql(u8, intZ, binder.interface_name)) {
                const bind_opq: *anyopaque = wl.wl_registry_bind(self.registry, id, binder.interface, version) orelse {
                    io.print("Failed to bind '{s}', terminating.\n", .{binder.interface_name});
                    unreachable;
                };

                binder.bind(bind_opq);
                return;
            }
        }
    }

    pub fn globalRegistryRemoveHandler(_: ?*anyopaque, _: ?*wl.struct_wl_registry, id: u32) callconv(.C) void {
        io.print("Received registry remove event for id: {d}\n", .{id});
        io.print("should probably do something about that huh.\n", .{});
    }
};
