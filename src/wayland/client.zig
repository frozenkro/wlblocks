const b = @import("models/binder.zig");
const std = @import("std");
const io = @import("../io_util.zig");
const shm = @import("shm.zig");
const reg = @import("registry.zig");
const comp = @import("compositor.zig");
const win = @import("window.zig");
const disp = @import("display.zig");
const mx = @import("../mtx/matrix.zig");
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
    WlCompositorNotFound,
    ShmCtxNotFound,
    WlDisplayNotFound,
};
const WaylandClientLoopError = error{DispatchFailed};
const WaylandClientDrawError = error{NotInitialized};
const AddListenerError = error{AddListenerFailed};

pub const WlClient = struct {
    display: *disp.WlDisplay,
    registry: *reg.WlRegistry,
    compositor: *comp.WlCompositor,
    shm: *shm.ShmContext,
    window: *win.WlWindow,
    surface: *wl.wl_surface,
    allocator: *const std.mem.Allocator,

    pub fn init(allocator: *const std.mem.Allocator) !WlClient {
        try disp.WlDisplay.init(allocator.*);
        const display: *disp.WlDisplay = disp.WlDisplay.instance orelse {
            return WaylandClientSetupError.WlDisplayNotFound;
        };
        errdefer disp.WlDisplay.deinit(allocator.*);

        try reg.WlRegistry.init(allocator.*, display.*);
        var registry: *reg.WlRegistry = reg.WlRegistry.instance orelse {
            return WaylandClientSetupError.WlRegistryNotFound;
        };
        errdefer reg.WlRegistry.deinit(allocator.*);

        try comp.WlCompositor.init(allocator.*);
        var compositor: *comp.WlCompositor = comp.WlCompositor.instance orelse {
            return WaylandClientSetupError.WlCompositorNotFound;
        };
        errdefer comp.WlCompositor.deinit(allocator.*);

        try shm.ShmContext.init(allocator.*);
        var shmCtx: *shm.ShmContext = shm.ShmContext.instance orelse {
            return WaylandClientSetupError.ShmCtxNotFound;
        };
        errdefer shm.ShmContext.deinit(allocator.*);

        try win.WlWindow.init(allocator.*);
        var window: *win.WlWindow = win.WlWindow.instance orelse {
            return WaylandClientSetupError.WlWindowNotFound;
        };
        errdefer win.WlWindow.deinit(allocator.*);

        const bindings = [_]b.Binder{
            compositor.binder(),
            window.binder(),
            shmCtx.binder(),
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
        try shmCtx.setupListeners();

        wl.wl_surface_commit(surface);
        roundtrip_result = wl.wl_display_roundtrip(display.display);
        if (roundtrip_result == -1) {
            return error.RoundtripFailed;
        }

        // Need to ensure initial window size is set before this is called
        try shmCtx.initBuffer(window.width, window.height);

        wl.wl_surface_attach(surface, shmCtx.buffer, 0, 0);
        wl.wl_surface_commit(surface);

        return WlClient{
            .display = display,
            .registry = registry,
            .compositor = compositor,
            .surface = surface,
            .shm = shmCtx,
            .window = window,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *WlClient) void {
        wl.wl_surface_destroy(self.surface);

        shm.ShmContext.deinit(self.allocator.*);
        comp.WlCompositor.deinit(self.allocator.*);
        reg.WlRegistry.deinit(self.allocator.*);
        win.WlWindow.deinit(self.allocator.*);
        disp.WlDisplay.deinit(self.allocator.*);
    }

    pub fn clientLoop(self: *WlClient) !void {
        if (wl.wl_display_dispatch(self.display.display) < 0) {
            return WaylandClientLoopError.DispatchFailed;
        }
    }

    pub fn draw(self: *WlClient, mtx: mx.PixelMatrix) WaylandClientDrawError!void {
        if (self.shm.shm_data == null) {
            return WaylandClientDrawError.NotInitialized;
        }
        shm.draw(mtx, self.shm.shm_data.?, self.window.dimensions());
    }
};
