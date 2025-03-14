const pm = @import("../mtx/pixel_matrix.zig");
pub const State = struct {
    .physicals = []Physical,
    .renderables = []Renderable,
};
pub const Physical = struct {
    coordinates: Coordinates,
    ptr: *anyopaque,
    tickPhysicsFn: *const fn (ptr: *anyopaque) void,
    pub fn tickPhysics(self: Physical) void {
        return self.tickPhysicsFn(self.ptr);
    }
};
pub const Renderable = struct {
    mtx: pm.PixelMatrix,
};
pub const Coordinates = struct { x: u32, y: u32 };
