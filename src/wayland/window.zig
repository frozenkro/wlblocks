const b = @import("binder.zig");
const xdg_shell = @cImport({
    @cInclude("xdg-shell.h");
});

pub const WlWindow = struct {
    base: ?*xdg_shell.xdg_wm_base,
    surface: ?*xdg_shell.xdg_surface,
    toplevel: ?*xdg_shell.xdg_toplevel,
    width: u32,
    height: u32,
    resized: bool,
    unknownSize: bool,

    pub fn init() WlWindow {
        return WlWindow{
            .base = null,
            .surface = null,
            .toplevel = null,
            .width = 0,
            .height = 0,
            .resized = false,
            .unknownSize = false,
        };
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
            .interface = &xdg_shell.xdg_wm_base_interface,
            .version = 1,
        };
    }
};
