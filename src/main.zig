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

    std.debug.print("User {?}\n", .{steamworks.SteamUser().GetSteamID()});

    raylib.SetConfigFlags(raylib.ConfigFlags{ .FLAG_WINDOW_RESIZABLE = true });
    raylib.InitWindow(800, 800, "hello world!");
    raylib.SetTargetFPS(60);

    defer raylib.CloseWindow();

    while (!raylib.WindowShouldClose()) {
        raylib.BeginDrawing();
        defer raylib.EndDrawing();

        raylib.ClearBackground(raylib.BLACK);
        raylib.DrawFPS(10, 10);

        raylib.DrawText("hello world!", 100, 100, 20, raylib.YELLOW);
    }
}

test "simple test" {
    try main();
}
