// A raylib port of https://github.com/raysan5/raylib/blob/master/examples/text/text_format_text.c

// Build Space Invaders
// Tasks:
//       - Tests!
//  Done - Get spaceship sprite to show up
//  Done - Get spaceship to move when direction keys are pressed
//  Done - Draw obstacles using an array.
//  Done - Get One bullet to shoot from space ship to work
//  Done - Get multiple bullets to shoot from ship
//       - Refactor missiles to be inside player ship
//       - Get collision detection to work with bullets and obstacles
//       - Implement damage/points logic when collision detection occurs between bullets and obstacles
//       - Make obstacles move
//       - Replace obstacle's default rectangle with animated invader sprite

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

// TODO: Refactor this. Detect wall SHOULD NOT modify rec.
//       It should just return true if wall is detected and false if not.
//       The caller should then modify the rec position if needed.
//       This would mean that we probably need more than a boolean returned.
//       Probably need an enum to with Top, Bottom, Left, Right instead.

fn detectWall(rec: *rl.Rectangle, stop_at_wall: bool) !bool {
    const screen_width: f32 = @floatFromInt(rl.getScreenWidth());
    const screen_height: f32 = @floatFromInt(rl.getScreenHeight());

    if ((rec.x + (rec.width / 2)) >= screen_width) {
        if (stop_at_wall)
            rec.x = screen_width - rec.width;
        return true;
    } else if (rec.x <= (rec.width) / 2) {
        if (stop_at_wall)
            rec.x = (rec.width) / 2;
        return true;
    } else if ((rec.y + (rec.height / 2)) >= screen_height) {
        if (stop_at_wall)
            rec.y = screen_height - rec.height;
        return true;
    } else if (rec.y <= (rec.height) / 2) {
        if (stop_at_wall)
            rec.y = (rec.height) / 2;
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

var POINTS: u32 = 0;

const Missile = struct {
    const vel: f32 = 0.2;

    const height = 10;
    const width = 5;
    rec: ?rl.Rectangle = null,
    fired: bool = false,
    wall_detected: bool = false,

    fn fire(self: *Missile) !void {
        self.fired = true;
        rl.drawRectangle(@intFromFloat(self.rec.?.x), @intFromFloat(self.rec.?.y), Missile.width, Missile.height, rl.Color.white);
    }

    fn move(self: *Missile) !void {
        if (self.fired == true) {
            std.debug.assert(self.rec != null);
            self.rec.?.y -= Missile.vel;
            if (try detectWall(&self.rec.?, false)) {
                if (!self.wall_detected) POINTS += 1;
                self.wall_detected = true;
                self.rec.?.x = -1;
                self.rec.?.y = -1;
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

    fn handleWeapons(self: *Ship) !void {
        if (rl.isKeyPressed(rl.KeyboardKey.space)) {
            try self.weapons_bay.?.append(blk: {
                var missile = Missile{ .rec = .{ .x = self.rec.x, .y = self.rec.y - self.rec.height, .width = Missile.width, .height = Missile.height } };
                try missile.fire();
                break :blk missile;
            });
        }
        for (self.weapons_bay.?.slice()) |*missile| {
            try missile.move();
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

    // var missile_array = try std.BoundedArray(Missile, 1024 * 10).init(0);
    try player_ship.initWeaponsBay();

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
        rl.drawText(rl.textFormat("Elapsed Time: %02.02f ms", .{rl.getFrameTime() * 1000}), 0, 0, 20, .white);

        // FIX: This is just a POC. No points should be given for shooting the top.
        rl.drawText(rl.textFormat("Points: %d ", .{POINTS}), 0, 20, 20, .white);

        _ = try detectWall(&player_ship.rec, true);
        try player_ship.handleSpaceshipMovement();
        try player_ship.handleWeapons();

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
