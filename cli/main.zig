const std = @import("std");
const storage = @import("storage");
const page = storage.page;
const stdout = std.io.getStdOut().writer();
const Dir = std.fs.Dir;
const File = std.fs.File;
const testing = std.testing;
const print = std.debug.print;

pub fn main() !void {

    // allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // get arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // if more than 1 argument provider -- exit
    if (args.len > 2) {
        std.debug.print("Usage: {s} <database path> ...\n", .{args[0]});
        return;
    }

    // path given by user
    const db_path = args[1];

    var file_handle: std.fs.File = getDbFileHandle(db_path) catch |err| {
        std.debug.print("Could not get file handle.\n{}\n", .{err});
        return;
    };

    defer file_handle.close();

    const stat = try file_handle.stat();
    const db_file_name: []const u8 = std.fs.path.basename(db_path);

    if (stat.size == 0) {
        // initiate database
        // return prompt to operate on database
    } else {
        // read database
        // return prompt to operate on database
    }
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
