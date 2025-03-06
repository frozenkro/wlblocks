const b = @import("binder.zig");
const std = @import("std");
const io = @import("../io_util.zig");
const xdg = @import("xdg.zig");
const shm = @import("shm.zig");
const reg = @import("registry.zig");
const comp = @import("compositor.zig");
const win = @import("window.zig");
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

pub const WlClient = struct {
    display: *disp.WlDisplay,
    registry: *reg.WlRegistry,
    compositor: *comp.WlCompositor,
    shm: *shm.WlShm,
    window: *win.WlWindow,

    fn shmFormatHandler(_: ?*anyopaque, _: ?*wl.wl_shm, format: u32) callconv(.C) void {
        io.print("Format {d}\n", .{format});
    }

    const shm_listener: wl.wl_shm_listener = .{
        .format = shmFormatHandler,
    };

    pub fn init() !WlClient {
        const display = try disp.WlDisplay.init();
        const registry = try reg.WlRegistry.init(display);

        const compositor = comp.WlCompositor.init();
        const window = win.WlWindow.init();
        const wlShm = shm.WlShm.init();

        const bindings = [_]b.Binder{
            compositor.binder(),
            window.binder(),
            wlShm.binder(),
        };
        registry.register(bindings);

        const add_listener_result = wl.wl_registry_add_listener(registry, &reg.WlRegistry.registry_listener, null);
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

        const surface = wl.wl_compositor_create_surface(compositor) orelse return error.SurfaceCreationFailed;
        io.print("Created a surface\n", .{});

        try addListeners(surface, shm_listener);

        wl.wl_surface_commit(surface);
        roundtrip_result = wl.wl_display_roundtrip(display);
        if (roundtrip_result == -1) {
            return error.RoundtripFailed;
        }
        const buffer = try shm.create_buffer(xdg.width, xdg.height);

        wl.wl_surface_attach(surface, buffer, 0, 0);
        wl.wl_surface_commit(surface);

        return WlClient{
            .display = display,
            .registry = registry,
            .compositor = compositor,
            .surface = surface,
            .buffer = buffer,
        };
    }

    pub fn deinit(self: *WlClient) void {
        wl.wl_surface_destroy(self.surface);
        wl.wl_display_disconnect(self.display);
    }

    pub fn clientLoop(self: *WlClient) !void {
        if (wl.wl_display_dispatch(self.display) < 0) {
            return WaylandClientLoopError.DispatchFailed;
        }
    }
};
fn addListeners(surface: *wl.struct_wl_surface, shm_listener: *wl.wl_shm_listener) AddListenerError!void {
    var cIntRes: c_int = 0;
    // add listener to wm base
    cIntRes = xdg_shell.xdg_wm_base_add_listener(xdg.xdg_wm_base, &xdg.xdg_wm_base_listener, null);
    if (cIntRes != 0) {
        return error.AddListenerFailed;
    }

    // create xdg surface
    xdg.xdg_surface = xdg_shell.xdg_wm_base_get_xdg_surface(xdg.xdg_wm_base, @ptrCast(surface));
    cIntRes = xdg_shell.xdg_surface_add_listener(xdg.xdg_surface, &xdg.xdg_surface_listener, null);
    if (cIntRes != 0) {
        return error.AddListenerFailed;
    }

    // set toplevel role for xdg surface
    xdg.xdg_toplevel = xdg_shell.xdg_surface_get_toplevel(xdg.xdg_surface);
    cIntRes = xdg_shell.xdg_toplevel_add_listener(xdg.xdg_toplevel, &xdg.xdg_toplevel_listener, null);
    if (cIntRes != 0) {
        return error.AddListenerFailed;
    }

    cIntRes = wl.wl_shm_add_listener(shm.shm, &shm_listener, null);
    if (cIntRes != 0) {
        return error.AddListenerFailed;
    }
}
