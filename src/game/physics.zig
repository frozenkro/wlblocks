const ste = @import("state.zig");
const mtx = @import("../mtx/pixel_matrix.zig");
const std = @import("std");

var delta: u32 = 0;
var prev_time = std.time.nanoTimestamp();
var new_time: u32 = 0;

pub fn tick(state: ste.State) void {
    // process physics
    // ...

    new_time = std.time.nanoTimestamp();
    delta = new_time - prev_time;
    std.time.sleep(delta);
}
