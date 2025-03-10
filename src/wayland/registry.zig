const b = @import("binder.zig");
const disp = @import("display.zig");
const io = @import("../io_util.zig");
const std = @import("std");
const wl = @cImport({
    @cInclude("wayland-client.h");
});

pub const RegistryError = error{GetRegistryFailed} || std.mem.Allocator.Error;

pub const WlRegistry = struct {
    registry: *wl.struct_wl_registry,
    binders: ?[*]const b.Binder = null,
    binders_len: i32 = 0,

    pub var instance: ?*WlRegistry = null;

    pub const registry_listener: wl.struct_wl_registry_listener = .{ .global = globalRegistryHandler, .global_remove = globalRegistryRemoveHandler };

    /// Returns nothing because this is a singleton.
    /// Access instance at `WlRegistry.instance`.
    pub fn init(allocator: std.mem.Allocator, display: disp.WlDisplay) RegistryError!void {
        const registry = wl.wl_display_get_registry(display.display) orelse {
            return RegistryError.GetRegistryFailed;
        };

        const wl_registry = try allocator.create(WlRegistry);
        wl_registry.* = WlRegistry{
            .registry = registry,
        };
        WlRegistry.instance = wl_registry;
    }

    pub fn deinit(allocator: std.mem.Allocator) void {
        if (WlRegistry.instance == null) {
            io.print("Warning: Nothing to deinit\n", .{});
            return;
        }

        allocator.destroy(WlRegistry.instance.?);
        WlRegistry.instance = null;
    }

    pub fn register(self: *WlRegistry, binders: [*]const b.Binder, binders_len: i32) void {
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
