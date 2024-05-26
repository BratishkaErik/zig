const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const os = std.os;
const fs = std.fs;
const Compilation = @import("Compilation.zig");
const build_options = @import("build_options");

const getWasiPreopen = @import("main.zig").getWasiPreopen;

/// Returns the sub_path that worked, or `null` if none did.
/// The path of the returned Directory is relative to `base`.
/// The handle of the returned Directory is open.
fn testZigInstallPrefix(base_dir: fs.Dir) ?Compilation.Directory {
    const test_index_file = "std" ++ fs.path.sep_str ++ "std.zig";

    zig_dir: {
        // Try lib/zig/std/std.zig
        const lib_zig = "lib" ++ fs.path.sep_str ++ "zig";
        var test_zig_dir = base_dir.openDir(lib_zig, .{}) catch break :zig_dir;
        const file = test_zig_dir.openFile(test_index_file, .{}) catch {
            test_zig_dir.close();
            break :zig_dir;
        };
        file.close();
        return Compilation.Directory{ .handle = test_zig_dir, .path = lib_zig };
    }

    // Try lib/std/std.zig
    var test_zig_dir = base_dir.openDir("lib", .{}) catch return null;
    const file = test_zig_dir.openFile(test_index_file, .{}) catch {
        test_zig_dir.close();
        return null;
    };
    file.close();
    return Compilation.Directory{ .handle = test_zig_dir, .path = "lib" };
}

/// This is a small wrapper around selfExePathAlloc that adds support for WASI
/// based on a hard-coded Preopen directory ("/zig")
pub fn findZigExePath(allocator: mem.Allocator) ![]u8 {
    if (builtin.os.tag == .wasi) {
        @compileError("this function is unsupported on WASI");
    }

    return fs.selfExePathAlloc(allocator);
}

/// Both the directory handle and the path are newly allocated resources which the caller now owns.
pub fn findZigLibDir(gpa: mem.Allocator) !Compilation.Directory {
    const self_exe_path = try findZigExePath(gpa);
    defer gpa.free(self_exe_path);

    return findZigLibDirFromSelfExe(gpa, self_exe_path);
}

/// Both the directory handle and the path are newly allocated resources which the caller now owns.
pub fn findZigLibDirFromSelfExe(
    allocator: mem.Allocator,
    self_exe_path: []const u8,
) error{
    OutOfMemory,
    FileNotFound,
    CurrentWorkingDirectoryUnlinked,
    Unexpected,
}!Compilation.Directory {
    const cwd = fs.cwd();
    var cur_path: []const u8 = self_exe_path;
    while (fs.path.dirname(cur_path)) |dirname| : (cur_path = dirname) {
        var base_dir = cwd.openDir(dirname, .{}) catch continue;
        defer base_dir.close();

        const sub_directory = testZigInstallPrefix(base_dir) orelse continue;
        const p = try fs.path.join(allocator, &[_][]const u8{ dirname, sub_directory.path.? });
        defer allocator.free(p);
        return Compilation.Directory{
            .handle = sub_directory.handle,
            .path = try resolvePath(allocator, p),
        };
    }
    return error.FileNotFound;
}

/// Returns global cache directory.
/// `path` field is an absolute path in all cases except WASI
/// (WASI does not have concept of absolute pathes).
///
/// Caller owns:
///  * `handle` field,
///  * if host OS is not WASI, also owns `path` field.
pub fn resolveGlobalCacheDir(allocator: mem.Allocator, override_from_arg: ?[]const u8) !std.Build.Cache.Directory {
    if (builtin.os.tag == .wasi) {
        // Simplified logic, WASI does not have concept of absolute pathes.
        if (override_from_arg) |override|
            return .{
                .path = override,
                .handle = try fs.cwd().makeOpenPath(override, .{}),
            }
        else
            return getWasiPreopen("/cache");
    }

    const original_path = orig: {
        if (override_from_arg) |override| break :orig try allocator.dupe(u8, override);

        const override_from_env = try std.zig.EnvVar.ZIG_GLOBAL_CACHE_DIR.get(allocator);
        if (override_from_env) |override| break :orig override;

        const appname = "zig";

        if (builtin.os.tag != .windows) {
            if (std.zig.EnvVar.XDG_CACHE_HOME.getPosix()) |cache_root|
                break :orig try fs.path.join(allocator, &[_][]const u8{ cache_root, appname })
            else if (std.zig.EnvVar.HOME.getPosix()) |home|
                break :orig try fs.path.join(allocator, &[_][]const u8{ home, ".cache", appname });
        }

        break :orig try fs.getAppDataDir(allocator, appname);
    };

    std.log.err("original_path = {s}", .{original_path});
    const absolute_path = if (fs.path.isAbsolute(original_path))
        original_path
    else absolute: {
        std.log.err("original_path is not absolute! Converting to absolute...", .{});
        defer allocator.free(original_path);

        const cwd_path = try std.process.getCwdAlloc(allocator);
        defer allocator.free(cwd_path);
        std.log.err("cwd_path = {s}", .{cwd_path});

        std.log.err("Converting...", .{});
        break :absolute try fs.path.resolve(allocator, &.{ cwd_path, original_path });
    };
    std.log.err("absolute_path = {s}", .{absolute_path});

    return .{
        .path = absolute_path,
        .handle = try fs.cwd().makeOpenPath(absolute_path, .{}),
    };
}

/// Similar to std.fs.path.resolve, with a few important differences:
/// * If the input is an absolute path, check it against the cwd and try to
///   convert it to a relative path.
/// * If the resulting path would start with a relative up-dir ("../"), instead
///   return an absolute path based on the cwd.
/// * When targeting WASI, fail with an error message if an absolute path is
///   used.
pub fn resolvePath(
    ally: mem.Allocator,
    p: []const u8,
) error{
    OutOfMemory,
    CurrentWorkingDirectoryUnlinked,
    Unexpected,
}![]u8 {
    if (fs.path.isAbsolute(p)) {
        const cwd_path = try std.process.getCwdAlloc(ally);
        defer ally.free(cwd_path);
        const relative = try fs.path.relative(ally, cwd_path, p);
        if (isUpDir(relative)) {
            ally.free(relative);
            return ally.dupe(u8, p);
        } else {
            return relative;
        }
    } else {
        const resolved = try fs.path.resolve(ally, &.{p});
        if (isUpDir(resolved)) {
            ally.free(resolved);
            const cwd_path = try std.process.getCwdAlloc(ally);
            defer ally.free(cwd_path);
            return fs.path.resolve(ally, &.{ cwd_path, p });
        } else {
            return resolved;
        }
    }
}

/// TODO move this to std.fs.path
pub fn isUpDir(p: []const u8) bool {
    return mem.startsWith(u8, p, "..") and (p.len == 2 or p[2] == fs.path.sep);
}
