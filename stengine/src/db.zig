const std = @import("std");

pub const DataBase = struct {
    file: std.fs.File,

    pub fn init(file_path: []const u8) !DataBase {
        const file = try std.fs.cwd().createFile(file_path, .{ .write = true, .read = true, .truncate = true });
        return DataBase{ .file = file };
    }
};
