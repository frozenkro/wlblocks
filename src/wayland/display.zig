const wl = @cImport({
    @cInclude("wayland-client.h");
});

pub const DisplayError = error{ConnectFailed};

pub const WlDisplay = struct {
    display: *wl.struct_wl_display,

    pub fn init() DisplayError!WlDisplay {
        const display = wl.wl_display_connect(null) orelse return DisplayError.ConnectFailed;
        return WlDisplay{ .display = display };
    }

    pub fn deinit(self: *WlDisplay) void {
        wl.wl_display_disconnect(self.display);
    }
};
