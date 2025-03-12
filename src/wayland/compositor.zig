const b = @import("models/binder.zig");
const io = @import("../io_util.zig");
const std = @import("std");
const wl = @cImport({
    @cInclude("wayland-client.h");
});

pub const WlCompositor = struct {
    compositor: ?*wl.struct_wl_compositor,

    pub var instance: ?*WlCompositor = null;

    pub fn init(allocator: std.mem.Allocator) std.mem.Allocator.Error!void {
        WlCompositor.instance = try allocator.create(WlCompositor);
        WlCompositor.instance.?.* = .{ .compositor = null };
    }

    pub fn deinit(allocator: std.mem.Allocator) void {
        if (WlCompositor.instance == null) {
            io.print("Warning: Nothing to deinit\n", .{});
        }
        allocator.destroy(WlCompositor.instance.?);
    }

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
