const b = @import("binder.zig");
const wl = @cImport({
    @cInclude("wayland-client.h");
});

pub const WlShm = struct {
    shm: wl.wl_shm,
    buffer: [*]u32 = undefined,

    fn bind(ptr: *anyopaque, shm: *anyopaque) void {
        const self: *WlShm = @ptrCast(@alignCast(ptr));
        self.shm = @ptrCast(shm);
    }

    pub fn binder(self: *WlShm) b.Binder {
        return .{
            .ptr = self,
            .bindFn = bind,
            .interface_name = "wl_shm",
            .interface = &wl.wl_shm_interface,
            .version = 1,
        };
    }
};
