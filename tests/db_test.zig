const std = @import("std");
const tst = std.testing;
const print = std.debug.print;
const storage = @import("storage");
const deebee = @import("db").db;
const Database = deebee.Database;
const cli_helpers = @import("cli").helpers;

test "db_init_existing" {
    const allocator = std.testing.allocator;
    const db_path = "./tests/artifacts/test.db";

    const abs_db_path = try std.fs.realpathAlloc(allocator, db_path);
    defer allocator.free(abs_db_path);

    var db = try Database.init(allocator, abs_db_path, false);
    defer db.deinit();

    try tst.expectEqual(db.buffer_manager.page_directory.metadata.page_count, 2);
}

test "db_init_new" {
    const allocator = std.testing.allocator;
    const db_path = "./tests/artifacts/test_newdb";
    const abs_path = try cli_helpers.getAbsPath(allocator, db_path);
    defer allocator.free(abs_path);

    var db = try Database.init(allocator, abs_path, false);
    try db.persist();
    defer db.deinit();

    try tst.expectEqual(db.buffer_manager.page_directory.metadata.page_count, 2);
}
