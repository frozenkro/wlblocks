const b = @import("binder.zig");
const wl = @cImport({
    @cInclude("wayland-client.h");
});

pub const WlCompositor = struct {
    compositor: ?*wl.struct_wl_compositor,

    fn bind(ptr: *anyopaque, compositor_opq: *anyopaque) void {
        const self: *WlCompositor = @ptrCast(@alignCast(ptr));
        self.compositor = @ptrCast(compositor_opq);
    }

    pub fn binder(self: *WlCompositor) b.Binder {
        return .{
            .ptr = self,
            .bindFn = bind,
            .interface_name = "wl_compositor",
            .interface = &wl.wl_compositor_interface,
            .version = 4,
        };
    }
};
