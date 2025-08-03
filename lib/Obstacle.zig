const rl = @import("raylib");

pub const Obstacle = @This();

rec: rl.Rectangle,
hit_count: u2 = 0,
dead: bool = false,

pub fn hit(self: *Obstacle) !void {
    if (self.hit_count >= 2) self.dead = true else self.hit_count += 1;
}
