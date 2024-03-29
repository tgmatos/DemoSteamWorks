const std = @import("std");
const raylib = @import("src/raylib/build.zig");
const zig_steamworks = @import("src/zig-steamworks/build.zig");

pub fn addLibraryPath(compile: *std.build.Step.Compile) void {
    //std.debug.print("\n\n\nOS: {any}", .{compile.target.os_tag.?});
    if (compile.target.os_tag != null and compile.target.os_tag.? == .macos) {
        compile.step.dependOn(&compile.step.owner.addInstallBinFile(.{ .path = "src/zig-steamworks/steamworks/redistributable_bin/osx/libsteam_api.dylib" }, "libsteam_api.dylib").step);
        compile.step.dependOn(&compile.step.owner.addInstallBinFile(.{ .path = "src/zig-steamworks/steamworks/public/steam/lib/osx/libsdkencryptedappticket.dylib" }, "libsdkencryptedappticket.dylib").step);
        compile.addLibraryPath(.{ .path = "src/zig-steamworks/steamworks/public/steam/lib/osx" });
        compile.addLibraryPath(.{ .path = "src/zig-steamworks/steamworks/redistributable_bin/osx" });
    } else if (compile.target.os_tag != null and compile.target.os_tag.? == .windows) {
        compile.step.dependOn(&compile.step.owner.addInstallBinFile(.{ .path = "src/zig-steamworks/steamworks/public/steam/lib/win64/sdkencryptedappticket64.dll" }, "sdkencryptedappticket64.dll").step);
        compile.step.dependOn(&compile.step.owner.addInstallBinFile(.{ .path = "src/zig-steamworks/steamworks/redistributable_bin/win64/steam_api64.dll" }, "steam_api64.dll").step);
        compile.addLibraryPath(.{ .path = "src/zig-steamworks/steamworks/public/steam/lib/win64" });
        compile.addLibraryPath(.{ .path = "src/zig-steamworks/steamworks/redistributable_bin/win64" });
    } else {
        std.debug.print("\n\nEntrou no else\n", .{});
        compile.step.dependOn(&compile.step.owner.addInstallBinFile(.{ .path = "src/zig-steamworks/steamworks/redistributable_bin/linux64/libsteam_api.so" }, "libsteam_api.so").step);
        compile.step.dependOn(&compile.step.owner.addInstallBinFile(.{ .path = "src/zig-steamworks/steamworks/public/steam/lib/linux64/libsdkencryptedappticket.so" }, "libsdkencryptedappticket.so").step);
        compile.addLibraryPath(.{ .path = "src/zig-steamworks/steamworks/public/steam/lib/linux64" });
        compile.addLibraryPath(.{ .path = "src/zig-steamworks/steamworks/redistributable_bin/linux64" });
        // instructs the binary to load libraries from the local path
    }
}

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "rb-zig",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    raylib.addTo(b, exe, target, optimize, .{});

    // Steamworks
    const module = b.addModule("steamworks", .{
        .source_file = .{ .path = "src/zig-steamworks/src/main.zig" },
    });

    var lib = b.addStaticLibrary(.{
        .name = "steamworks",
        .root_source_file = .{ .path = "src/zig-steamworks/src/steam.cpp" },
        .target = target,
        .optimize = optimize,
    });

    lib.linkLibC();
    lib.linkLibCpp();

    var flagContainer = std.ArrayList([]const u8).init(std.heap.page_allocator);
    if (optimize != .Debug) flagContainer.append("-Os") catch unreachable;
    flagContainer.append("-Wno-return-type-c-linkage") catch unreachable;
    flagContainer.append("-fno-sanitize=undefined") catch unreachable;
    flagContainer.append("-Wgnu-alignof-expression") catch unreachable;
    flagContainer.append("-Wno-gnu") catch unreachable;

    addLibraryPath(lib);

    if (lib.target.os_tag != null and lib.target.os_tag.? == .windows) {
        lib.linkSystemLibrary("sdkencryptedappticket64");
        lib.linkSystemLibrary("steam_api64");
    } else {
        lib.linkSystemLibrary("sdkencryptedappticket");
        lib.linkSystemLibrary("steam_api");
    }

    lib.addIncludePath(.{ .path = "src/zig-steamworks/steamworks/public/steam" });
    lib.addCSourceFiles(&.{"src/zig-steamworks/src/steam.cpp"}, flagContainer.items);
    // End Steamworks

    addLibraryPath(exe);
    //zig_steamworks.addLibraryPath(exe);

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    exe.linkLibrary(lib);
    exe.addModule("steamworks", module);
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
