const go = @import("game_object.zig");
const GameObject = go.GameObject;
const ObjectOptions = go.ObjectOptions;
const std = @import("std");
const ArrayList = std.ArrayList;
pub const State = struct {
    collidables: ArrayList(*GameObject),
    visibles: ArrayList(*GameObject),
    movables: ArrayList(*GameObject),

    pub fn init(allocator: std.mem.Allocator) std.mem.Allocator.Error!State {
        const collidables = try ArrayList(*GameObject).init(allocator);
        const visibles = try ArrayList(*GameObject).init(allocator);
        const movables = try ArrayList(*GameObject).init(allocator);
        return .{
            .collidables = collidables,
            .visibles = visibles,
            .movables = movables,
        };
    }
    pub fn deinit(self: State) void {
        self.collidables.deinit();
        self.visibles.deinit();
        self.movables.deinit();
    }

    pub fn addGameObject(self: State, obj: GameObject, opts: ObjectOptions) std.mem.Allocator.Error!void {
        if (opts.collidable) {
            try self.collidables.append(obj);
        }
        if (opts.visible) {
            try self.visibles.append(obj);
        }
        if (opts.movable) {
            try self.movables.append(obj);
        }
    }
};

// Every tick, each GameObject has its movement evaluated and returns a proposed "next state"
// all collidables then have their "next state" coordinates+hitboxes evaluated using a hashmap distinct algo
// any collidables that would have occupied the same space must not be allowed to move
