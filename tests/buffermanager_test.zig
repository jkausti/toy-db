const std = @import("std");
const tst = std.testing;
const print = std.debug.print;
const storage = @import("storage");

const BufferManager = storage.buffermanager.BufferManager;
const PageBuffer = storage.page_buffer.PageBuffer;
const PageDirectory = storage.page_directory.PageDirectory;
const DataType = storage.data_type.DataType;
const Column = storage.column.Column;
const Tuple = storage.tuple.Tuple;

test "masterSchema" {
    const columns = BufferManager.masterSchema();
    try tst.expect(columns.len == 5);
    try tst.expect(columns[0] == DataType.String);
    try tst.expect(columns[1] == DataType.String);
    try tst.expect(columns[2] == DataType.BigInt);
    try tst.expect(columns[3] == DataType.String);
    try tst.expect(columns[4] == DataType.String);
}

test "init_BufferManager" {
    const allocator = std.testing.allocator;
    const file = try std.fs.cwd().createFile("test.db", .{ .read = true, .truncate = true });

    var buffer_manager = try BufferManager.init(allocator, "urmom69", null);
    defer buffer_manager.deinit();

    const master_root_page = buffer_manager.master_root_page;

    const schema = BufferManager.masterSchema();
    const schema_heap = try allocator.dupe(DataType, &schema);
    defer allocator.free(schema_heap);
    const tuples = try master_root_page.getTuples(schema_heap);
    defer {
        for (tuples) |t| {
            t.deinit();
        }
        allocator.free(tuples);
    }

    try tst.expect(tuples.len == 5);
    try buffer_manager.flush(file);
}

test "flush" {
    const allocator = std.testing.allocator;
    var buffer_manager = try BufferManager.init(allocator, "urmom69", null);
    const file = try std.fs.cwd().createFile("test.db", .{ .read = true, .truncate = false });

    defer buffer_manager.deinit();
    defer file.close();

    // Use the public flush method instead of the private flushHeaderMasterPage
    try buffer_manager.flush(file);
}

test "updateMaster" {
    const allocator = std.testing.allocator;
    var buffer_manager = try BufferManager.init(allocator, "urmom69", null);
    defer buffer_manager.deinit();

    const columns = [3]Column{
        Column{ .name = "id", .data_type = DataType.BigInt },
        Column{ .name = "name", .data_type = DataType.String },
        Column{ .name = "age", .data_type = DataType.Int },
    };
    const columns_slice = try allocator.dupe(Column, &columns);
    defer allocator.free(columns_slice);

    const schema_name = "main";
    const table_name = "people";

    _ = try buffer_manager.updateMaster(columns_slice, schema_name, table_name, 10);

    const master_schema = BufferManager.masterSchema();
    const master_schema_slice = try allocator.dupe(DataType, &master_schema);
    defer allocator.free(master_schema_slice);
    const updated_master_root_page_tuples = try buffer_manager.master_root_page.getTuples(master_schema_slice);
    defer {
        for (updated_master_root_page_tuples) |t| {
            t.deinit();
        }
        allocator.free(updated_master_root_page_tuples);
    }

    try tst.expect(updated_master_root_page_tuples.len == 8);
}

test "createTable" {
    const allocator = std.testing.allocator;
    const file = try std.fs.cwd().createFile("test.db", .{ .read = true, .truncate = true });

    var buffer_manager = try BufferManager.init(allocator, "urmom69", null);
    defer buffer_manager.deinit();

    const columns = [3]Column{
        Column{ .name = "id", .data_type = DataType.BigInt },
        Column{ .name = "name", .data_type = DataType.String },
        Column{ .name = "age", .data_type = DataType.Int },
    };

    const columns_slice = try allocator.dupe(Column, &columns);
    defer allocator.free(columns_slice);

    const schema_name = "main";
    const table_name = "people";

    const master_schema = BufferManager.masterSchema();
    const master_schema_slice = try allocator.dupe(DataType, &master_schema);
    defer allocator.free(master_schema_slice);

    const master_root_page_tuples = try buffer_manager.master_root_page.getTuples(master_schema_slice);

    defer {
        for (master_root_page_tuples) |t| {
            t.deinit();
        }
        allocator.free(master_root_page_tuples);
    }

    // get the next page_id
    // looping through tuples and looking at third column (root_page)
    // new page_id will be the max of all the page_ids + 1
    var next_page_id: i64 = 0;
    for (master_root_page_tuples) |t| {
        const page_id = switch (t.data[2]) {
            .bigint_value => |val| val,
            else => unreachable,
        };
        if (page_id > next_page_id) {
            next_page_id = page_id;
        }
    }
    next_page_id += 1;

    // insert new data into master page

    try buffer_manager.updateMaster(columns_slice, schema_name, table_name, next_page_id);

    // create new page and add to page_directory
    const new_page = try PageBuffer.init(allocator, 4096);

    const new_page_offset = try buffer_manager.addPage(new_page);
    try buffer_manager.page_directory.insertPageDirEntry(@intCast(next_page_id), new_page_offset);

    // flush buffer_manager to disk
    try buffer_manager.flush(file);

    // test that the new page is in the page_directory
    const page_dir_schema = try PageDirectory.getSchema();
    const page_directory_tuples = try buffer_manager.page_directory.page.getTuples(page_dir_schema);
    defer {
        for (page_directory_tuples) |t| {
            t.deinit();
        }
        allocator.free(page_directory_tuples);
    }
    try tst.expect(page_directory_tuples.len == 3);
}

test "initFromDisk" {
    const allocator = std.testing.allocator;
    const file = try std.fs.cwd().openFile("test.db", .{});
    defer file.close();

    var buffer_manager = try BufferManager.init(allocator, null, file);
    defer buffer_manager.deinit();

    // Check that the master root page is initialized correctly
    const master_schema = BufferManager.masterSchema();
    const master_schema_slice = try allocator.dupe(DataType, &master_schema);
    defer allocator.free(master_schema_slice);
    const master_page_tuples = try buffer_manager.master_root_page.getTuples(master_schema_slice);
    defer {
        for (master_page_tuples) |t| {
            t.deinit();
        }
        allocator.free(master_page_tuples);
    }

    // print("{s}", .{buffer_manager.page_directory.metadata.signature});

    try tst.expect(master_page_tuples.len > 0);
    try tst.expect(std.mem.eql(u8, buffer_manager.page_directory.metadata.signature, "dbstar2"));

    // for (master_page_tuples) |t| {
    //     // const page_id = switch (t.data[2]) {
    //     //     .bigint_value => |val| val,
    //     //     else => unreachable,
    //     // };
    //     // try tst.expect(page_id == 0);
    //     print("{any}", .{t});
    // }
    // print("{any}", .{buffer_manager.page_directory.metadata});
}
