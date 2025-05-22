const mx = @import("../../mtx/matrix.zig");

pub const Angle = f32;
pub const Distance = f32;

pub const GameObject = struct {
    sprite: ?mx.PixelMatrix,
    hitbox: mx.CollisionMatrix,
    coordinates: ?Coordinates,
    speed: Distance,
    orientation: Angle,

};

pub const Coordinates = struct { 
    x: u32, 
    y: u32,

    pub fn Move(self: *Coordinates, angle: Angle, distance: Distance) void {
        const x_delta: Distance = distance * @cos(angle);
        const y_delta: Distance = distance * @sin(angle);

        self.x += x_delta;
        self.y += y_delta;
    }
};

pub const ObjectOptions = struct {
    collidable: bool,
    visible: bool,
    movable: bool,
};
