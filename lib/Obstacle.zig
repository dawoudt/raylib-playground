const rl = @import("raylib");
const std = @import("std");

const Dir = enum { up, down, left, right };
pub const Texture = struct {
    src: rl.Texture,
    rec: rl.Rectangle,

    pub fn init() Texture {
        const src = rl.loadTexture("assets/textures/cat_inverted.png") catch @panic("Couldn't load texture");
        const frame_h: f32 = @floatFromInt(src.height);
        const sprite_width: f32 = @floatFromInt(src.width);
        const frame_w = sprite_width;
        return .{ .src = src, .rec = .{ .x = 0, .y = 0, .width = frame_w, .height = frame_h } };
    }

    pub fn deinit(self: *Texture) void {
        rl.unloadTexture(self.src);
        self.* = undefined;
    }
};

pub const Obstacle = @This();

rec: rl.Rectangle,
hit_count: u2 = 0,
dead: bool = false,
move_counter: u32 = 0,
texture: ?Texture = null,

const movement = [_]Dir{
    .left,
    .left,
    .left,
    .left,
    .down,
    .right,
    .right,
    .right,
    .right,
    .down,
};

pub fn hit(self: *Obstacle) !void {
    if (self.hit_count >= 2) self.dead = true else self.hit_count += 1;
}

pub fn nextMove(self: *Obstacle) Dir {
    defer self.move_counter += 1;
    return movement[@mod(self.move_counter, movement.len)];
}

pub fn move(self: *Obstacle) void {
    const num_of_pixels = 10.0;
    const next_move = self.nextMove();
    switch (next_move) {
        .left => self.rec.x += -num_of_pixels,
        .right => self.rec.x += num_of_pixels,
        .down => self.rec.y += num_of_pixels,
        .up => self.rec.y += -num_of_pixels,
    }
}
