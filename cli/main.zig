const std = @import("std");
// const storage = @import("storage");
// const PageBuffer = storage.page_buffer;
const db = @import("db");
const Database = db.db.Database;
const stdout = std.io.getStdOut().writer();
const Dir = std.fs.Dir;
const File = std.fs.File;
const testing = std.testing;
const print = std.debug.print;

const DbstarError = error{
    NotImplemented,
};

pub fn main() !void {

    // allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // get arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // if more than 1 argument provided -- exit
    if (args.len > 2) {
        std.debug.print("Usage: {s} <database path> ...\n", .{args[0]});
        return;
    }

    // path given by user
    const db_path = args[1];

    const path_exist = try pathExist(db_path);
    const is_absolute = std.fs.path.isAbsolute(db_path);
    var abs_path: []const u8 = undefined;
    var abs_path_alloced = false;

    if (path_exist and !is_absolute) {
        const cwd = std.fs.cwd();
        abs_path = cwd.realpathAlloc(allocator, db_path) catch |err| {
            std.debug.print("Error getting absolute path for: {s}\n", .{db_path});
            return err;
        };
        abs_path_alloced = true;
    } else if (path_exist and is_absolute) {
        std.debug.print("Database file exists and path given is absolute: {s}\n", .{db_path});
        abs_path = db_path;
    } else if (!path_exist and is_absolute) {
        std.debug.print("Database file does not exist and path given is absolute: {s}\n", .{db_path});
        abs_path = db_path;
        return DbstarError.NotImplemented;
    } else if (!path_exist and !is_absolute) {
        const cwd = std.fs.cwd();
        const file = cwd.createFile(db_path, .{ .read = true, .truncate = false }) catch |err| {
            std.debug.print("Error creating file: {s}\n", .{db_path});
            return err;
        };
        defer file.close();

        return DbstarError.NotImplemented;
    } else {
        std.debug.print("Error: Unknown error occurred.\n", .{});
        return error.UnknownError;
    }
    defer {
        if (abs_path_alloced) {
            allocator.free(abs_path);
        }
    }

    var db_instance = try Database.init(allocator, abs_path, path_exist);
    defer db_instance.deinit();
}

fn pathExist(path: []const u8) !bool {
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

pub fn getDbFileHandle(path: []const u8) !File {
    const db_file_name: []const u8 = std.fs.path.basename(path);

    const cwd = std.fs.cwd();
    const dir_path: ?[]const u8 = std.fs.path.dirname(path);

    // if only file name is given
    if (dir_path == null) {
        const file_handle = try cwd.createFile(db_file_name, .{ .read = true, .truncate = false });
        return file_handle;
    }
    var db_dir: Dir = undefined;

    if (std.fs.path.isAbsolute(path)) {
        db_dir = std.fs.openDirAbsolute(dir_path.?, .{ .iterate = false }) catch |err| {
            print("Could not open directory: {s}\n", .{dir_path.?});
            return err;
        };
    } else {
        db_dir = cwd.openDir(dir_path.?, .{ .iterate = false }) catch |err| {
            print("Could not open directory: {s}\n", .{dir_path.?});
            return err;
        };
    }

    defer db_dir.close();
    const file_handle = try db_dir.createFile(db_file_name, .{ .read = true, .truncate = false });
    return file_handle;
}

test "getDbFileHandle" {
    const db_path = "tests/dummy_file.db";
    const file_handle = try getDbFileHandle(db_path);
    defer file_handle.close();
    const stat = try file_handle.stat();
    const file_size = stat.size;
    const expected_size = 0;
    try testing.expectEqual(file_size, expected_size);
}

test "pathExist" {
    const db_path_neg = "some_folder/dummy_file.db";
    const exists = try pathExist(db_path_neg);
    try testing.expectEqual(exists, false);

    const db_path_pos = "build.zig";
    const exists_absolute = try pathExist(db_path_pos);
    try testing.expectEqual(exists_absolute, true);
}
