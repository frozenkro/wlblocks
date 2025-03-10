const b = @import("binder.zig");
const std = @import("std");
const io = @import("../io_util.zig");
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
    WlRegistryNotFound,
    WlWindowNotFound,
};
const WaylandClientLoopError = error{DispatchFailed};
const AddListenerError = error{AddListenerFailed};

pub const WlClient = struct {
    display: *disp.WlDisplay,
    registry: *reg.WlRegistry,
    compositor: *comp.WlCompositor,
    shm: *shm.WlShm,
    window: *win.WlWindow,
    surface: *wl.wl_surface,
    allocator: *const std.mem.Allocator,

    pub fn init(allocator: *const std.mem.Allocator) !WlClient {
        var display = try disp.WlDisplay.init();
        try reg.WlRegistry.init(allocator.*, display);
        var registry: *reg.WlRegistry = reg.WlRegistry.instance orelse {
            return WaylandClientSetupError.WlRegistryNotFound;
        };
        errdefer reg.WlRegistry.deinit(allocator.*);

        var compositor = comp.WlCompositor.init();
        var wlShm = shm.WlShm.init();

        try win.WlWindow.init(allocator.*);
        var window: *win.WlWindow = win.WlWindow.instance orelse {
            return WaylandClientSetupError.WlWindowNotFound;
        };
        errdefer win.WlWindow.deinit(allocator.*);

        const bindings = [_]b.Binder{
            compositor.binder(),
            window.binder(),
            wlShm.binder(),
        };
        registry.register(&bindings, 3);

        const add_listener_result = wl.wl_registry_add_listener(registry.registry, &reg.WlRegistry.registry_listener, null);
        if (add_listener_result != 0) {
            return WaylandClientSetupError.AddListenerFailed;
        }

        const dispatch_result = wl.wl_display_dispatch(display.display);
        if (dispatch_result == -1) {
            return WaylandClientSetupError.DispatchFailed;
        }

        var roundtrip_result = wl.wl_display_roundtrip(display.display);
        if (roundtrip_result == -1) {
            return WaylandClientSetupError.RoundtripFailed;
        }

        if (compositor.compositor == null) {
            return WaylandClientSetupError.CompositorConnectFailed;
        }

        const surface = wl.wl_compositor_create_surface(compositor.compositor) orelse return error.SurfaceCreationFailed;
        io.print("Created a surface\n", .{});

        try window.setupListeners(surface);
        try wlShm.setupListeners();

        wl.wl_surface_commit(surface);
        roundtrip_result = wl.wl_display_roundtrip(display.display);
        if (roundtrip_result == -1) {
            return error.RoundtripFailed;
        }
        try wlShm.initBuffer(window.width, window.height);

        wl.wl_surface_attach(surface, wlShm.buffer, 0, 0);
        wl.wl_surface_commit(surface);

        return WlClient{
            .display = &display,
            .registry = registry,
            .compositor = &compositor,
            .surface = surface,
            .shm = &wlShm,
            .window = window,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *WlClient) void {
        wl.wl_surface_destroy(self.surface);
        wl.wl_display_disconnect(self.display.display);

        reg.WlRegistry.deinit(self.allocator.*);
        win.WlWindow.deinit(self.allocator.*);
    }

    pub fn clientLoop(self: *WlClient) !void {
        if (wl.wl_display_dispatch(self.display.display) < 0) {
            return WaylandClientLoopError.DispatchFailed;
        }
    }
};
