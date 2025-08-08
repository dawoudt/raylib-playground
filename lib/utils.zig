const rl = @import("raylib");
const std = @import("std");
const Obstacle = @import("Obstacle");

pub fn log(comptime level: rl.TraceLogLevel, comptime text: []const u8, args: anytype) void {
    var buf: [8194]u8 = undefined;
    const out = try std.fmt.bufPrintZ(&buf, text, args);
    rl.traceLog(level, out, .{});
}

var keys_pressed = std.BoundedArray([*c]const u8, 4096).init(0) catch {};

pub fn drawKeyPress() void {
    const key = rl.getKeyPressed();
    if (key != .null) {
        const key_name = @as([*c]const u8, @tagName(key));
        try keys_pressed.append(key_name);
    }
    if (keys_pressed.len > 0) {
        var y_delta: i32 = 0;
        for (keys_pressed.constSlice()) |kn| {
            y_delta += 20;
            rl.drawText(rl.textFormat("Key Pressed: %s ", .{kn}), 0, y_delta, 20, .white);
        }
    }
}

// TODO: Refactor this. Detect wall SHOULD NOT modify rec.
//       It should just return true if wall is detected and false if not.
//       The caller should then modify the rec position if needed.
//       This would mean that we probably need more than a boolean returned.
//       Probably need an enum to with Top, Bottom, Left, Right instead.
pub fn detectWall(rec: *rl.Rectangle, stop_at_wall: bool) bool {
    const screen_width: f32 = @floatFromInt(rl.getScreenWidth());
    const screen_height: f32 = @floatFromInt(rl.getScreenHeight());

    if ((rec.x + (rec.width / 2)) >= screen_width) {
        if (stop_at_wall)
            rec.x = screen_width - rec.width;
        return true;
    }

    if (rec.x <= (rec.width) / 2) {
        if (stop_at_wall)
            rec.x = (rec.width) / 2;
        return true;
    }

    if ((rec.y + (rec.height / 2)) >= screen_height) {
        if (stop_at_wall)
            rec.y = screen_height - rec.height;
        return true;
    }

    if (rec.y <= (rec.height) / 2) {
        if (stop_at_wall)
            rec.y = (rec.height) / 2;
        return true;
    }
    return false;
}

pub fn generateObstacles(block_pixel_size: u32, block_arr: anytype, obstacles: *std.BoundedArray(Obstacle, 1024)) !void {
    const base_starting_x = 0.0;
    var current_x: u32 = base_starting_x;

    var y_delta: u32 = 1;
    for (block_arr) |row| {
        defer current_x = base_starting_x;
        defer y_delta += 1;
        for (row) |val| {
            defer current_x += block_pixel_size;
            if (val == 1) {
                try obstacles.append(.{
                    .rec = .{
                        .x = @floatFromInt(current_x),
                        .y = @floatFromInt((y_delta + 1) * block_pixel_size),
                        .height = @floatFromInt(block_pixel_size),
                        .width = @floatFromInt(block_pixel_size),
                    },
                });
            }
        }

        // rl.drawRectangle(@intCast(current_x), 100, @intCast(block_pixel_size), @intCast(block_pixel_size), rl.Color.dark_gray);
    }
}

pub fn drawBlocks(obstacles: []Obstacle) void {
    for (obstacles) |*obstacle| {
        // const x: i32 = @intFromFloat(obstacle.rec.x);
        // const y: i32 = @intFromFloat(obstacle.rec.y);
        // const width: i32 = @intFromFloat(obstacle.rec.width);
        // const height: i32 = @intFromFloat(obstacle.rec.height);
        // rl.drawRectangle(x, y, width, height, rl.Color.dark_gray);

        if (obstacle.texture == null) obstacle.texture = Obstacle.Texture.init();

        rl.drawTexturePro(
            obstacle.texture.?.src,
            obstacle.texture.?.rec,
            obstacle.rec,
            .{ .x = 0, .y = 0 },
            0,
            rl.Color.white,
        );
    }
}

pub fn deinitObstacleTextures(obstacles: []Obstacle) void {
    for (obstacles) |*obstacle| {
        if (obstacle.texture != null) obstacle.texture.?.deinit();
    }
}
