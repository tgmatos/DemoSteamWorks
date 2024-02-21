const std = @import("std");
const raylib = @import("raylib");
const steamworks = @import("steamworks");

/// callback hook for debug text emitted from the Steam API
pub fn SteamAPIDebugTextHook(nSeverity: c_int, pchDebugText: [*c]const u8) callconv(.C) void {
    // if you're running in the debugger, only warnings (nSeverity >= 1) will be sent
    // if you add -debug_steamapi to the command-line, a lot of extra informational messages will also be sent
    std.debug.print("SteamAPIDebugTextHook sev:{} msg: {s}\n", .{ nSeverity, pchDebugText });
}

pub fn main() !void {
    if (steamworks.SteamAPI_Init()) {
        std.debug.print("Steam initialized with success\n", .{});
    } else {
        std.debug.print("\n\nNot initialized\n\n", .{});
        @panic("Steam not initialized");
    }

    steamworks.SteamClient().SetWarningMessageHook(SteamAPIDebugTextHook);
    defer steamworks.SteamAPI_Shutdown();

    var id = steamworks.SteamUser().GetSteamID();
    std.debug.print("User {d}\n", .{id});

    var name = steamworks.SteamFriends().GetPersonaName();

    std.debug.print("Type: {any}\nName: {s}\n", .{ @TypeOf(name), name });

    raylib.SetConfigFlags(raylib.ConfigFlags{ .FLAG_WINDOW_RESIZABLE = true });
    raylib.InitWindow(500, 500, "Hello World");
    raylib.SetTargetFPS(60);

    defer raylib.CloseWindow();

    var x: i32 = 0;
    var y: i32 = 0;

    while (!raylib.WindowShouldClose()) {
        if (x < 250) {
            x += 1;
            y += 1;
        }

        raylib.BeginDrawing();
        defer raylib.EndDrawing();

        raylib.ClearBackground(raylib.BLACK);
        raylib.DrawFPS(10, 10);

        raylib.DrawText(name, x, y, 20, raylib.YELLOW);
    }
}

test "simple test" {
    try main();
}
