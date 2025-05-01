const std = @import("std");
const tst = std.testing;
const print = std.debug.print;
const storage = @import("storage");
const deebee = @import("db").db;
const Database = deebee.Database;

test "db_init" {
    const allocator = std.testing.allocator;
    const db_path = "test.db";

    const abs_db_path = try std.fs.realpathAlloc(allocator, db_path);
    defer allocator.free(abs_db_path);

    var db = try Database.init(allocator, abs_db_path, false);
    defer db.deinit();

    try tst.expectEqual(db.buffer_manager.page_directory.metadata.page_count, 2);
}
