const std = @import("std");
const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();
const Allocator = std.mem.Allocator;
const helpers = @import("helpers.zig");
const pathExist = helpers.pathExist;
const getAbsPath = helpers.getAbsPath;
const db = @import("db");
const Database = db.db.Database;
const Dir = std.fs.Dir;
const File = std.fs.File;
const testing = std.testng;
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
    const db_exists = try pathExist(db_path);
    const abs_path = try getAbsPath(allocator, db_path);
    defer allocator.free(abs_path);

    var db_instance = try Database.init(allocator, abs_path, db_exists);
    _ = db_instance.persist() catch |err| {
        std.debug.print("Error flushing buffer.\n", .{});
        return err;
    };

    // give user prompt to interact with the database
    //
    try stdout.print("\nWelcomez toz ze databaze built with zzzig...🐊\n\n", .{});

    while (true) {
        try stdout.print("zdb >> ", .{});

        const input = try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', 8192);
        defer allocator.free(input.?);

        if (std.mem.eql(u8, input.?, ".q")) {
            try stdout.print("Byezzz...🐊\n", .{});
            break;
        } else if (std.mem.eql(u8, input.?, "help")) {
            // print help message
            try stdout.print("\n", .{});
            try stdout.print("Available commands:\n", .{});
            try stdout.print("  - .help: show this message\n", .{});
            try stdout.print("  - .q: quit the program\n", .{});
            try stdout.print("\n", .{});
        } else {
            // parse input into AST
            const ast = 
        }
    }

    defer db_instance.deinit();
}

test "pathExist" {
    const db_path_neg = "some_folder/dummy_file.db";
    const exists = try pathExist(db_path_neg);
    try testing.expectEqual(exists, false);

    const db_path_pos = "build.zig";
    const exists_absolute = try pathExist(db_path_pos);
    try testing.expectEqual(exists_absolute, true);
}
