const b = @import("binder.zig");
const io = @import("../io_util.zig");
const std = @import("std");
const xdg_shell = @cImport({
    @cInclude("xdg-shell.h");
});
const wl = @cImport({
    @cInclude("wayland-client.h");
});

pub const AddListenerError = error{AddListenerFailed};

pub const WlWindow = struct {
    base: ?*xdg_shell.xdg_wm_base,
    surface: ?*xdg_shell.xdg_surface,
    toplevel: ?*xdg_shell.xdg_toplevel,
    width: u32,
    height: u32,
    resized: bool,
    unknownSize: bool,

    pub var instance: ?*WlWindow = null;

    pub fn init(allocator: std.mem.Allocator) std.mem.Allocator.Error!void {
        const window = try allocator.create(WlWindow);
        window.* = WlWindow{
            .base = null,
            .surface = null,
            .toplevel = null,
            .width = 0,
            .height = 0,
            .resized = false,
            .unknownSize = false,
        };
        WlWindow.instance = window;
    }

    pub fn deinit(allocator: std.mem.Allocator) void {
        if (WlWindow.instance == null) {
            io.print("Warning: Nothing to deinit\n", .{});
            return;
        }

        allocator.destroy(WlWindow.instance.?);
        WlWindow.instance = null;
    }

    fn bind(ptr: *anyopaque, base_opq: *anyopaque) void {
        const self: *WlWindow = @ptrCast(@alignCast(ptr));
        self.base = @ptrCast(base_opq);
    }

    pub fn binder(self: *WlWindow) b.Binder {
        return .{
            .ptr = self,
            .bindFn = bind,
            .interface_name = "xdg_wm_base",
            .interface = @ptrCast(&xdg_shell.xdg_wm_base_interface),
            .version = 1,
        };
    }

    pub fn setupListeners(self: *WlWindow, surface: *wl.struct_wl_surface) AddListenerError!void {
        var cIntRes: c_int = 0;
        // add listener to wm base
        cIntRes = xdg_shell.xdg_wm_base_add_listener(self.base, &xdg_wm_base_listener, null);
        if (cIntRes != 0) {
            return AddListenerError.AddListenerFailed;
        }

        // create xdg surface
        self.surface = xdg_shell.xdg_wm_base_get_xdg_surface(self.base, @ptrCast(surface));
        cIntRes = xdg_shell.xdg_surface_add_listener(self.surface, &xdg_surface_listener, null);
        if (cIntRes != 0) {
            return AddListenerError.AddListenerFailed;
        }

        // set toplevel role for xdg surface
        self.toplevel = xdg_shell.xdg_surface_get_toplevel(self.surface);
        cIntRes = xdg_shell.xdg_toplevel_add_listener(self.toplevel, &xdg_toplevel_listener, null);
        if (cIntRes != 0) {
            return AddListenerError.AddListenerFailed;
        }
    }

    fn xdgWmBasePingHandler(_: ?*anyopaque, wm_base: ?*xdg_shell.xdg_wm_base, serial: u32) callconv(.C) void {
        xdg_shell.xdg_wm_base_pong(wm_base, serial);
    }

    pub const xdg_wm_base_listener: xdg_shell.xdg_wm_base_listener = .{ .ping = xdgWmBasePingHandler };

    fn xdgSurfaceConfigureHandler(_: ?*anyopaque, xs: ?*xdg_shell.xdg_surface, serial: u32) callconv(.C) void {
        xdg_shell.xdg_surface_ack_configure(xs, serial);
    }

    pub const xdg_surface_listener: xdg_shell.xdg_surface_listener = .{ .configure = xdgSurfaceConfigureHandler };

    fn xdgToplevelConfigureHandler(_: ?*anyopaque, _: ?*xdg_shell.xdg_toplevel, new_width: i32, new_height: i32, _: [*c]xdg_shell.wl_array) callconv(.C) void {
        io.print("xdg toplevel configure: {d}x{d}\n", .{ new_width, new_height });
        const self = WlWindow.instance.?;
        if (new_width < 0 or new_height < 0) {
            self.unknownSize = true;
            self.resized = true;
            return;
        }

        self.width = @intCast(new_width);
        self.height = @intCast(new_height);
        self.resized = true;
    }

    fn xdgToplevelCloseHandler(_: ?*anyopaque, _: ?*xdg_shell.xdg_toplevel) callconv(.C) void {
        io.print("closing xdg toplevel\n", .{});
    }

    pub const xdg_toplevel_listener: xdg_shell.xdg_toplevel_listener = .{
        .configure = xdgToplevelConfigureHandler,
        .close = xdgToplevelCloseHandler,
    };
};
