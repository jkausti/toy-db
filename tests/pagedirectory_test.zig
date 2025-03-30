const std = @import("std");
const tst = std.testing;
const print = std.debug.print;
const storage = @import("storage");
const AutoHashMap = std.AutoHashMap;

const BufferManager = storage.buffermanager.BufferManager;
const PageBuffer = storage.page_buffer.PageBuffer;
const PageDirectory = storage.page_directory.PageDirectory;
const DataType = storage.data_type.DataType;
const Column = storage.column.Column;
const Tuple = storage.tuple.Tuple;
const DbMetadata = storage.page_directory.DbMetadata;

test "DbMetadata" {
    const allocator = tst.allocator;
    const metadata = DbMetadata{
        .signature = "dbstar2",
        .db_name = "test_db",
        .page_count = 1,
    };

    const buf = try metadata.serialize(allocator);
    defer allocator.free(buf);
    const deserialized = try DbMetadata.deserialize(buf);

    try tst.expect(std.mem.eql(u8, metadata.signature, deserialized.signature));
    try tst.expect(std.mem.eql(u8, metadata.db_name, deserialized.db_name));
    try tst.expect(metadata.page_count == deserialized.page_count);
}

test "PageDirectory" {
    const allocator = tst.allocator;

    var page_dir = try PageDirectory.init(allocator, "test_db");
    defer page_dir.deinit();

    try tst.expect(std.mem.eql(u8, page_dir.metadata.signature, "dbstar2"));
    try tst.expect(std.mem.eql(u8, page_dir.metadata.db_name, "test_db"));
    try tst.expect(page_dir.metadata.page_count == 2);
}

test "PageDirectory_insert" {
    const allocator = tst.allocator;

    var page_dir = try PageDirectory.init(allocator, "test_db");
    defer page_dir.deinit();

    try page_dir.insertPageDirEntry(1, 0);
    try page_dir.insertPageDirEntry(1, 0);

    const buf = try page_dir.serialize();
    defer allocator.free(buf);
    const deserialized = try PageDirectory.deserialize(allocator, buf);

    try tst.expect(std.mem.eql(u8, page_dir.metadata.signature, deserialized.metadata.signature));
    try tst.expect(std.mem.eql(u8, page_dir.metadata.db_name, deserialized.metadata.db_name));
    try tst.expect(page_dir.metadata.page_count == deserialized.metadata.page_count);
}

test "PageDirectory_getOffset" {
    const allocator = tst.allocator;

    var page_dir = try PageDirectory.init(allocator, "test_db");
    defer page_dir.deinit();

    const page_1_offset = try page_dir.getOffset(0);
    const page_2_offset = try page_dir.getOffset(1);

    try tst.expect(page_1_offset == 0);
    try tst.expect(page_2_offset == 8192);
}

test "fillPageMap" {
    const allocator = tst.allocator;

    var page_dir = try PageDirectory.init(allocator, "test_db");
    defer page_dir.deinit();

    var map = AutoHashMap(i32, i64).init(allocator);
    defer map.deinit();

    try page_dir.fillPageMap(&map);

    const offset1 = map.get(0);
    try tst.expect(offset1.? == 0);

    const offset2 = map.get(1);
    try tst.expect(offset2.? == 8192);
}
