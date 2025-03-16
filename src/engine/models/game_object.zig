const mx = @import("../../mtx/matrix.zig");

pub const GameObject = struct {
    sprite: ?mx.PixelMatrix,
    hitbox: mx.CollisionMatrix,
    coordinates: ?Coordinates,
    speed: f32,
    orientation: f32,
};

pub const Coordinates = struct { x: u32, y: u32 };

pub const ObjectOptions = struct {
    collidable: bool,
    visible: bool,
    movable: bool,
};
