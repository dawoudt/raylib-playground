// A raylib port of https://github.com/raysan5/raylib/blob/master/examples/text/text_format_text.c

// Build Space Invaders
// Tasks:
//       - Tests!
//  Done - Get spaceship sprite to show up
//  Done - Get spaceship to move when direction keys are pressed
//  Done - Draw obstacles using an array.
//  Done - Get One bullet to shoot from space ship to work
//  Done - Get multiple bullets to shoot from ship
//  Done - Refactor missiles to be inside player ship
//  Done - Get collision detection to work with bullets and obstacles
//  Done - Implement damage/points logic when collision detection occurs between bullets and obstacles
//  Done - Make obstacles move
//  Done - Replace obstacle's default rectangle with animated invader sprite
//  Done - Add finish game state
//       - Clean up/Reorganize

const rl = @import("raylib");
const std = @import("std");
const Obstacle = @import("Obstacle");
const utils = @import("utils");

const FPS = 60;

const windowWidth = 800;
const windowHeight = 450;

pub fn main() !void {
    // Initialization
    //--------------------------------------------------------------------------------------

    rl.setConfigFlags(.{ .window_highdpi = true });

    rl.initWindow(windowWidth, windowHeight, "Space Invaders!");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setWindowState(.{ .window_resizable = true });
    rl.clearBackground(rl.Color.ray_white);
    rl.endDrawing(); // Need this here or inits weird :/

    try gameLoop(FPS);
}

const Direction = enum(i2) {
    L = -1,
    R = 1,
    None = 0,
};

var POINTS: u32 = 0;

var obstacles_array = std.BoundedArray(Obstacle, 1024).init(0) catch {};

const Missile = struct {
    const vel: f32 = 0.2;

    const height = 10;
    const width = 5;
    rec: ?rl.Rectangle = null,
    fired: bool = false,
    wall_hit: bool = false,
    obstacle_hit: bool = false,

    fn fire(self: *Missile) !void {
        self.fired = true;
        rl.drawRectangle(@intFromFloat(self.rec.?.x), @intFromFloat(self.rec.?.y), Missile.width, Missile.height, rl.Color.white);
    }

    // Violates Single responsibility. Move should just move. It should handle wall and obstacle detection.
    fn move(self: *Missile, obstacles: *std.BoundedArray(Obstacle, 1024)) !void {
        if (self.fired == true) {
            std.debug.assert(self.rec != null);
            self.rec.?.y -= Missile.vel;
            if (utils.detectWall(&self.rec.?, false)) {
                self.wall_hit = true;
            }
            for (obstacles.slice(), 0..) |*o, index| {
                const collided = rl.checkCollisionRecs(self.rec.?, o.rec);
                if (collided) {
                    if (!self.obstacle_hit) POINTS += 1;
                    self.obstacle_hit = true;
                    try o.hit();
                    if (o.dead) {
                        _ = obstacles_array.orderedRemove(index);
                    }
                }
            }
            rl.drawRectangle(@intFromFloat(self.rec.?.x), @intFromFloat(self.rec.?.y), Missile.width, Missile.height, rl.Color.white);
        }
    }
};

// TODO: re write weapons bay logic so that we have an array with the initial number of Missiles.
//       Then when fired, they move into a fired array that we iterate through and update the y pos.
//       This would make much more sense logically compared to what we have now. We could then use initWeaponsBay()
//       to add the initial number of missiles as well.

const Ship = struct {
    const velocity_default = 0.1;
    const velocity_delta = 0.000255;
    rec: rl.Rectangle,
    vel: f32 = Ship.velocity_default,
    weapons_bay: ?std.BoundedArray(Missile, 1024 * 10) = null,

    fn initWeaponsBay(self: *Ship) !void {
        if (self.weapons_bay == null)
            self.weapons_bay = try std.BoundedArray(Missile, 1024 * 10).init(0);
    }

    fn handleWeaponFire(self: *Ship) !void {
        if (rl.isKeyPressed(rl.KeyboardKey.space)) {
            try self.weapons_bay.?.append(blk: {
                var missile = Missile{ .rec = .{ .x = self.rec.x - 2, .y = self.rec.y - self.rec.height, .width = Missile.width, .height = Missile.height } };
                try missile.fire();
                break :blk missile;
            });
        }

        for (self.weapons_bay.?.slice(), 0..) |*missile, index| {
            var m: *Missile = missile;
            try m.move(&obstacles_array);
            if (m.obstacle_hit or m.wall_hit)
                _ = self.weapons_bay.?.orderedRemove(index);
        }
    }

    pub fn handleSpaceshipMovement(self: *Ship) !void {
        // var dir = 0;
        if (rl.isKeyUp(rl.KeyboardKey.right) and rl.isKeyUp(rl.KeyboardKey.left))
            self.vel = Ship.velocity_default;

        if (rl.isKeyDown(rl.KeyboardKey.right)) {
            const dir: f32 = @floatFromInt(@intFromEnum(Direction.R));
            self.vel += Ship.velocity_delta;
            self.rec.x += self.vel * dir;
        }
        if (rl.isKeyDown(rl.KeyboardKey.left)) {
            const dir: f32 = @floatFromInt(@intFromEnum(Direction.L));
            self.vel += Ship.velocity_delta;
            self.rec.x += self.vel * dir;
        }
    }
};

// Used for generating obstacles

var block_array = [_][25]u32{
    [_]u32{ 0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 0 },
    [_]u32{ 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 1, 0 },
    // [_]u32{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    // [_]u32{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
};

const obstacle_pixel_size: u32 = 32; // 32*32

const enableDrawKeyPress = false;
const velocity_default = 0.1;
const velocity_delta = 0.000255;

var initialized = false;

fn gameLoop(frame_per_second: u8) !void {
    rl.setTargetFPS(frame_per_second);
    rl.beginDrawing();
    defer rl.endDrawing();
    const spaceship = try rl.loadTexture("assets/textures/inverted_spaceship.png");
    defer rl.unloadTexture(spaceship);
    const spaceship_sprite_width: f32 = @floatFromInt(@divExact(spaceship.width, 4));
    const spaceship_sprite_height: f32 = @floatFromInt(spaceship.height);

    var source_rec: rl.Rectangle = .{
        .height = spaceship_sprite_height,
        .width = spaceship_sprite_width,
        .x = 0,
        .y = 0,
    };

    var player_ship: Ship = .{
        .rec = .{
            .height = 48,
            .width = 48,
            .x = (windowWidth / 2),
            .y = windowHeight,
        },
    };

    try player_ship.initWeaponsBay();

    var sprite_frame_counter: f32 = 0.0;

    const ship_animation_frame_rate: u32 = 400;
    const obstacle_animation_frame_rate: u32 = 1600;
    var animation_frame_counter: u32 = 0;
    try utils.generateObstacles(obstacle_pixel_size, block_array, &obstacles_array);
    defer utils.deinitObstacleTextures(obstacles_array.slice());

    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        defer rl.endDrawing();
        animation_frame_counter += 1;
        if (obstacles_array.len == 0) {
            rl.clearBackground(.black);
            var out: [256]u8 = undefined;
            const text = try std.fmt.bufPrintZ(&out, "You go {d} points!\nGame Over", .{POINTS});
            const font = try rl.getFontDefault();
            const font_size: f32 = 40;
            const spacing: f32 = 1.0;

            const size = rl.measureTextEx(font, text, font_size, spacing);
            const pos = rl.Vector2{ .x = @as(f32, @floatFromInt(windowWidth)) / 2.0, .y = @as(f32, @floatFromInt(windowHeight)) / 2.0 };
            const origin = rl.Vector2{ .x = size.x / 2.0, .y = size.y / 2.0 };

            rl.drawTextPro(font, text, pos, origin, 0.0, font_size, spacing, rl.Color.white);
        } else {
            rl.clearBackground(rl.Color.black);
            rl.drawText(rl.textFormat("Elapsed Time: %02.02f ms", .{rl.getFrameTime() * 1000}), 0, 0, 20, .white);

            if (enableDrawKeyPress) try utils.drawKeyPress();

            rl.drawText(rl.textFormat("Points: %d ", .{POINTS}), 0, 20, 20, .white);

            _ = utils.detectWall(&player_ship.rec, true);
            try player_ship.handleSpaceshipMovement();
            try player_ship.handleWeaponFire();

            // TODO: Move ship animation logic inside Ship.
            if (@mod(animation_frame_counter, ship_animation_frame_rate) == 0) {
                const sprite_num: f32 = @as(f32, @mod(sprite_frame_counter, 4));

                source_rec.x = spaceship_sprite_width * sprite_num;
                sprite_frame_counter += 1;
            }
            utils.drawBlocks(obstacles_array.slice());

            if (@mod(animation_frame_counter, obstacle_animation_frame_rate) == 0) {
                for (obstacles_array.slice()) |*obstacle| {
                    var obs: *Obstacle = obstacle;
                    obs.move();
                }
            }

            rl.drawTexturePro(
                spaceship,
                source_rec,
                player_ship.rec,
                .{ .x = player_ship.rec.width / 2, .y = player_ship.rec.height / 2 },
                0,
                rl.Color.white,
            );
        }
    }
}
