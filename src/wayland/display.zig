const std = @import("std");
const io = @import("../io_util.zig");
const wl = @cImport({
    @cInclude("wayland-client.h");
});

pub const DisplayError = error{ConnectFailed} || std.mem.Allocator.Error;

pub const WlDisplay = struct {
    display: *wl.struct_wl_display,

    pub var instance: ?*WlDisplay = null;

    pub fn init(allocator: std.mem.Allocator) DisplayError!void {
        const display = wl.wl_display_connect(null) orelse return DisplayError.ConnectFailed;
        WlDisplay.instance = try allocator.create(WlDisplay);
        WlDisplay.instance.?.* = .{ .display = display };
    }

    pub fn deinit(allocator: std.mem.Allocator) void {
        if (instance == null) {
            io.print("Warning: Nothing to deinit\n", .{});
        }
        wl.wl_display_disconnect(WlDisplay.instance.?.display);
        allocator.destroy(WlDisplay.instance.?);
    }
};
