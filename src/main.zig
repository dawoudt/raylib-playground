// A raylib port of https://github.com/raysan5/raylib/blob/master/examples/text/text_format_text.c

// Build Space Invaders
// Tasks:
//  Done - Get spaceship sprite to show up
//  Done - Get spaceship to move when direction keys are pressed
//  Done - Draw obstacles using an array.
//  Done - Get One bullet to shoot from space ship to work
//  Done - Get multiple bullets to shoot from ship
//       - Get collision detection to work with bullets and obstacles
//       - Refactor missiles to be inside player (ship)

const rl = @import("raylib");
const std = @import("std");

fn log(comptime level: rl.TraceLogLevel, comptime text: []const u8, args: anytype) !void {
    var buf: [8194]u8 = undefined;
    const out = try std.fmt.bufPrintZ(&buf, text, args);
    rl.traceLog(level, out, .{});
}

const FPS = 60;

const windowWidth = 800;
const windowHeight = 400;

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

var keys_pressed = std.BoundedArray([*c]const u8, 4096).init(0) catch {};

fn drawKeyPress() !void {
    const key = rl.getKeyPressed();
    if (key != .null) {
        const key_name = @as([*c]const u8, @tagName(key));
        try keys_pressed.append(key_name);
    }
    if (keys_pressed.len > 0) {
        var y_delta: i32 = 0;
        for (keys_pressed.constSlice()) |kn| {
            y_delta += 20;
            rl.drawText(rl.textFormat("Key Pressed: %s ", .{kn}), 0, y_delta, 20, .black);
        }
    }
}

fn detectWall(rec: *rl.Rectangle) !bool {
    const screen_width: f32 = @floatFromInt(rl.getScreenWidth());

    if ((rec.x + (rec.width / 2)) >= screen_width) {
        rec.x = screen_width - rec.width;
        return true;
    } else if (rec.x <= (rec.width) / 2) {
        rec.x = (rec.width) / 2;
        return true;
    } else return false;
}

fn handleSpaceshipMovement(rec: *rl.Rectangle, velocity: *f32) !void {
    var direction: f32 = 0;

    if (rl.isKeyUp(rl.KeyboardKey.right) and rl.isKeyUp(rl.KeyboardKey.left))
        velocity.* = velocity_default;

    if (rl.isKeyDown(rl.KeyboardKey.right)) {
        direction = @floatFromInt(@intFromEnum(Direction.R));
        velocity.* += velocity_delta;
        rec.x += velocity.* * direction;
    }
    if (rl.isKeyDown(rl.KeyboardKey.left)) {
        direction = @floatFromInt(@intFromEnum(Direction.L));
        velocity.* += velocity_delta;
        rec.x += velocity.* * direction;
    }
}

const Direction = enum(i2) {
    L = -1,
    R = 1,
    None = 0,
};

const Missile = struct {
    const vel: f32 = 0.2;
    const height = 10;
    const width = 5;
    pos: ?rl.Vector2 = null,
    shot: bool = false,

    fn handleMissileFire(self: *Missile) !void {
        if (rl.isKeyPressed(rl.KeyboardKey.space)) {
            try self.shoot();
        } else try self.handleShotMovement();
    }

    fn shoot(self: *Missile) !void {
        self.shot = true;
        rl.drawRectangle(@intFromFloat(self.pos.?.x), @intFromFloat(self.pos.?.y), Missile.width, Missile.height, rl.Color.white);
    }

    fn handleShotMovement(self: *Missile) !void {
        if (self.shot == true) {
            std.debug.assert(self.pos != null);
            self.pos.?.y -= Missile.vel;
            rl.drawRectangle(@intFromFloat(self.pos.?.x), @intFromFloat(self.pos.?.y), Missile.width, Missile.height, rl.Color.white);
        }
    }
};

const Ship = struct {
    const velocity_default = 0.1;
    const velocity_delta = 0.000255;
    rec: rl.Rectangle,
    vel: f32 = Ship.velocity_default,

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

fn drawBlocks(block_pixel_size: u32, block_arr: []u32) !void {
    const base_starting_x = 0.0;
    var current_x: u32 = base_starting_x;

    for (block_arr) |val| {
        if (val == 1)
            rl.drawRectangle(@intCast(current_x), 100, @intCast(block_pixel_size), @intCast(block_pixel_size), rl.Color.dark_gray);
        current_x += block_pixel_size;
    }
}

const enableDrawKeyPress = false;
const velocity_default = 0.1;
const velocity_delta = 0.000255;

fn gameLoop(frame_per_second: u8) !void {
    rl.setTargetFPS(frame_per_second);
    rl.beginDrawing();
    defer rl.endDrawing();
    const spaceship = try rl.loadTexture("assets/textures/spaceship.png");
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
            .height = 32,
            .width = 32,
            .x = (windowWidth / 2),
            .y = windowHeight,
        },
    };

    var missile_array = try std.BoundedArray(Missile, 1024 * 10).init(0);

    var sprite_frame_counter: f32 = 0.0;

    const animation_frame_rate: i32 = 400;
    var animation_frame_counter: i32 = 0;

    const block_pixel_size: u32 = 32; // 32*32

    var block_arr = [_]u32{ 1, 0, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1 };

    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        defer rl.endDrawing();
        animation_frame_counter += 1;

        rl.clearBackground(rl.Color.black);
        if (enableDrawKeyPress) try drawKeyPress();

        _ = try detectWall(&player_ship.rec);
        try player_ship.handleSpaceshipMovement();

        if (rl.isKeyPressed(rl.KeyboardKey.space)) {
            try missile_array.append(blk: {
                var missile = Missile{ .pos = .{ .x = player_ship.rec.x, .y = player_ship.rec.y - player_ship.rec.height } };
                try missile.shoot();
                break :blk missile;
            });
        }
        for (missile_array.slice()) |*missile| {
            try missile.handleShotMovement();
        }

        rl.drawText(rl.textFormat("Elapsed Time: %02.02f ms", .{rl.getFrameTime() * 1000}), 0, 0, 20, .black);

        try drawBlocks(block_pixel_size, &block_arr);

        // TODO: Move ship animation logic inside Ship.
        if (@mod(animation_frame_counter, animation_frame_rate) == 0) {
            const sprite_num: f32 = @as(f32, @mod(sprite_frame_counter, 4));

            source_rec.x = spaceship_sprite_width * sprite_num;
            sprite_frame_counter += 1;
        }

        rl.drawTexturePro(
            spaceship,
            source_rec,
            player_ship.rec,
            .{ .x = player_ship.rec.width / 2, .y = player_ship.rec.height },
            0,
            rl.Color.white,
        );
    }
}
