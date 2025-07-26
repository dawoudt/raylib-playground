// A raylib port of https://github.com/raysan5/raylib/blob/master/examples/text/text_format_text.c

// Build Space Invaders
// Steps:
//  Done - Get spaceship sprite to show up
//  Done - Get spaceship to move when direction keys are pressed
//  Done - Draw obstacles using an array.
//  Done - Get One bullet to shoot from space ship to work
//       - Get multiple bullets to shoot from ship
//       - Get collision detection to work with bullets and obstacles

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

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------

    rl.setConfigFlags(.{ .window_highdpi = true });

    rl.initWindow(windowWidth, windowHeight, "raylib [text] example - text formatting");
    rl.beginDrawing();
    rl.clearBackground(rl.Color.ray_white);
    rl.endDrawing();

    defer rl.closeWindow(); // Close window and OpenGL context
    rl.setWindowState(.{ .window_resizable = true });
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

fn detectWall(rec: *rl.Rectangle) !void {
    const screen_width: f32 = @floatFromInt(rl.getScreenWidth());

    if ((rec.x + (rec.width / 2)) >= screen_width) {
        rec.x = screen_width - rec.width;
    } else if (rec.x <= (rec.width) / 2) {
        rec.x = (rec.width) / 2;
    }
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

const Player = struct {
    const velocity_default = 0.1;
    const velocity_delta = 0.000255;
    rec: rl.Rectangle,
    vel: f32 = Player.velocity_default,

    pub fn handleSpaceshipMovement(self: *Player) !void {
        // var dir = 0;
        if (rl.isKeyUp(rl.KeyboardKey.right) and rl.isKeyUp(rl.KeyboardKey.left))
            self.vel = Player.velocity_default;

        if (rl.isKeyDown(rl.KeyboardKey.right)) {
            const dir: f32 = @floatFromInt(@intFromEnum(Direction.R));
            self.vel += Player.velocity_delta;
            self.rec.x += self.vel * dir;
        }
        if (rl.isKeyDown(rl.KeyboardKey.left)) {
            const dir: f32 = @floatFromInt(@intFromEnum(Direction.L));
            self.vel += Player.velocity_delta;
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

// TODO: tidy up

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

    var player: Player = .{
        .rec = .{
            .height = 32,
            .width = 32,
            .x = (windowWidth / 2),
            .y = windowHeight,
        },
    };
    // player.rec = dest_rec;

    var sprite_frame_counter: f32 = 0.0;

    const animation_frame_rate: i32 = 400;
    var animation_frame_counter: i32 = 0;

    // var velocity: f32 = velocity_default;
    var missile = rl.Vector2{ .x = player.rec.x - 3, .y = player.rec.y - 20.0 };
    const missile_speed: f32 = 0.1;
    var missile_shot = false;

    const block_pixel_size: u32 = 32; // 32*32

    var block_arr = [_]u32{ 1, 0, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1 };

    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        defer rl.endDrawing();
        animation_frame_counter += 1;

        rl.clearBackground(rl.Color.black);
        if (enableDrawKeyPress) try drawKeyPress();

        try detectWall(&player.rec);
        try player.handleSpaceshipMovement();

        rl.drawText(rl.textFormat("Elapsed Time: %02.02f ms", .{rl.getFrameTime() * 1000}), 0, 0, 20, .black);

        try drawBlocks(block_pixel_size, &block_arr);

        if (@mod(animation_frame_counter, animation_frame_rate) == 0) {
            const sprite_num: f32 = @as(f32, @mod(sprite_frame_counter, 4));

            source_rec.x = spaceship_sprite_width * sprite_num;
            sprite_frame_counter += 1;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.space)) {
            missile_shot = true;
            missile.y = player.rec.y - player.rec.height;
            missile.x = player.rec.x;
        }
        if (missile_shot) {
            rl.drawRectangle(@intFromFloat(missile.x), @intFromFloat(missile.y), 5, 20, rl.Color.white);
            missile.y -= missile_speed;
        }

        rl.drawTexturePro(
            spaceship,
            source_rec,
            player.rec,
            .{ .x = player.rec.width / 2, .y = player.rec.height },
            0,
            rl.Color.white,
        );
    }
}
