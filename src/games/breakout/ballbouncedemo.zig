const std = @import("std");
const wc = @import("../../wayland/client.zig");
const ste = @import("../../engine/models/state.zig");
const obj = @import("../../engine/models/game_object.zig");
const physics = @import("../../engine/physics.zig");

pub fn ballbouncedemo() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    var wlclient = try wc.WlClient.init(&alloc);
    defer wlclient.deinit();

    var state = try ste.State.init(alloc);
    defer state.deinit();
    // var area = obj.GameObject{

    // };
    // TODO - create area and ball
    //

    while (true) {
        wlclient.clientLoop() catch { // could be a parallel process
            break;
        };
        physics.tick(state); // will sleep thread so loop is 60 / sec
        // TODO - implement physics motion/collision stuff
        // TODO - Create rendering namespace and function
        //        which assembles and draws all pixelmatrixes
    }
}
