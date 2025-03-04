const wl = @cImport({
    @cInclude("wayland-client.h");
});

pub const Binder = struct {
    ptr: *anyopaque,
    bindFn: *const fn (ptr: *anyopaque, binding: *anyopaque) void,
    interface_name: []const u8,
    interface: *wl.struct_wl_interface,
    version: u32,

    pub fn bind(self: Binder, binding: *anyopaque) void {
        return self.bindFn(binding);
    }
};
