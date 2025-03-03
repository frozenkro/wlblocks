const std = @import("std");
const io = @import("../io_util.zig");
const xdg = @import("xdg.zig");
const shm = @import("shm.zig");
const reg = @import("registry.zig");
const disp = @import("display.zig");
const wl = @cImport({
    @cInclude("wayland-client.h");
});
const xdg_shell = @cImport({
    @cInclude("xdg-shell.h");
});

const WaylandClientSetupError = error{
    AddListenerFailed,
    DispatchFailed,
    RoundtripFailed,
    CompositorConnectFailed,
};
const WaylandClientLoopError = error{DispatchFailed};
const AddListenerError = error{AddListenerFailed};

const WlClient = struct {
    display: *disp.WlDisplay,
    registry: *reg.WlRegistry,
    compositor: *wl.struct_wl_compositor,
    surface: *wl.struct_wl_surface,
    buffer: *wl.wl_buffer,

    c_int_res: c_int,

    // fn global_registry_handler(_: ?*anyopaque, _: ?*wl.struct_wl_registry, id: u32, interface: [*c]const u8, version: u32) callconv(.C) void {
    //     io.print("Received registry event for <{s}>, id: {d}, version: {d}.\n", .{ interface, id, version });

    //     const intZ: [:0]const u8 = std.mem.span(interface);
    //     if (std.mem.eql(u8, intZ, "wl_compositor")) {
    //         const compositor_opq: ?*anyopaque = wl.wl_registry_bind(registry, id, &wl.wl_compositor_interface, 4) orelse {
    //             io.print("Failed to bind wl_compositor, terminating.\n", .{});
    //             unreachable;
    //         };
    //         compositor = @ptrCast(compositor_opq);
    //     } else if (std.mem.eql(u8, intZ, "xdg_wm_base")) {
    //         const xdg_base_opq: ?*anyopaque = xdg_shell.wl_registry_bind(@ptrCast(registry), id, &xdg_shell.xdg_wm_base_interface, 1) orelse {
    //             io.print("Failed to bind xdg_wm_base, terminating.\n", .{});
    //             unreachable;
    //         };
    //         xdg.xdg_wm_base = @ptrCast(xdg_base_opq);
    //     } else if (std.mem.eql(u8, intZ, "wl_shm")) {
    //         const shm_opq: *anyopaque = wl.wl_registry_bind(registry, id, &wl.wl_shm_interface, 1) orelse {
    //             io.print("Failed to bind wl_shm, terminating.\n", .{});
    //             unreachable;
    //         };
    //         shm.shm = @ptrCast(shm_opq);
    //     }
    // }

    // fn global_registry_remove_handler(_: ?*anyopaque, _: ?*wl.struct_wl_registry, id: u32) callconv(.C) void {
    //     io.print("Received registry remove event for id: {d}", .{id});
    // }

    // const registry_listener: wl.struct_wl_registry_listener = .{ .global = global_registry_handler, .global_remove = global_registry_remove_handler };

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

    pub fn setCompositor(self: *WlClient, comp_opq: *anyopaque) void {
        self.compositor = @ptrCast(comp_opq);
    }
    pub fn setXdgWmBase(_: anytype, xdg_base_opq: *anyopaque) void {
        xdg.xdg_wm_base = @ptrCast(xdg_base_opq);
    }
    pub fn setShm(_: anytype, wl_shm_opq: *anyopaque) void {
        shm.shm = @ptrCast(wl_shm_opq);
    }
    
    pub fn init() !void {
        const display = try disp.WlDisplay.init();

        // Construct Registrations before creating WlRegistry
        const compositor_registration = reg.Registration(WlClient){
            .interface_name = "wl_compositor",
            .interface = &wl.wl_compositor_interface,
            .version = 4,
            .bind_set_callback = &setCompositor,
            .callback_inst = self,
        };
        const 

        // Get the registry to find available protocols
        registry = wl.wl_display_get_registry(display) orelse return error.GetRegistryFailed;
        const add_listener_result = wl.wl_registry_add_listener(registry, &registry_listener, null);
        if (add_listener_result != 0) {
            return WaylandClientSetupError.AddListenerFailed;
        }

        const dispatch_result = wl.wl_display_dispatch(display);
        if (dispatch_result == -1) {
            return WaylandClientSetupError.DispatchFailed;
        }

        var roundtrip_result = wl.wl_display_roundtrip(display);
        if (roundtrip_result == -1) {
            return WaylandClientSetupError.RoundtripFailed;
        }

        if (compositor == null) {
            return WaylandClientSetupError.CompositorConnectFailed;
        }

        surface = wl.wl_compositor_create_surface(compositor) orelse return error.SurfaceCreationFailed;
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
    }

    pub fn deinit() void {
        wl.wl_surface_destroy(surface);
        wl.wl_display_disconnect(display);
    }

    pub fn clientLoop() !void {
        if (wl.wl_display_dispatch(display) < 0) {
            return WaylandClientLoopError.DispatchFailed;
        }
    }
};
