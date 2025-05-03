const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn getAbsPath(allocator: Allocator, path: []const u8) ![]const u8 {
    const is_absolute = std.fs.path.isAbsolute(path);

    const abs_path = switch (is_absolute) {
        true => blk: {
            const path_buf = try allocator.alloc(u8, path.len);
            @memcpy(path_buf, path);
            break :blk path_buf;
        },
        false => blk: {
            const cwd_str = try std.process.getCwdAlloc(allocator);
            defer allocator.free(cwd_str);
            const abs_path = try std.fs.path.join(allocator, &.{ cwd_str, path });
            break :blk abs_path;
        },
    };
    return abs_path;
}

pub fn pathExist(path: []const u8) !bool {
    const is_absolute = std.fs.path.isAbsolute(path);

    return blk: {
        if (is_absolute) {
            _ = std.fs.openFileAbsolute(path, .{}) catch |err| switch (err) {
                error.FileNotFound, error.NotDir => break :blk false,
                else => return err,
            };
            break :blk true;
        } else {
            const cwd = std.fs.cwd();
            _ = cwd.openFile(path, .{}) catch |err| switch (err) {
                error.FileNotFound, error.NotDir => break :blk false,
                else => return err,
            };
            break :blk true;
        }
    };
}
