const std = @import("std");
const tst = std.testing;
const print = std.debug.print;
const ArrayList = std.ArrayList;
const File = std.fs.File;
const PageDirectory = @import("pagedirectory.zig").PageDirectory;
const PageBuffer = @import("page.zig").PageBuffer;
const DataType = @import("column.zig").DataType;
const Column = @import("column.zig").Column;
const CellValue = @import("cell.zig").CellValue;
const Tuple = @import("tuple.zig").Tuple;
const Allocator = std.mem.Allocator;

const MASTER_PAGE_START = 8192;
const MASTER_PAGE_SIZE = 4096;

pub const PageTableEntry = struct {
    offset: i64,
    page: PageBuffer,
    dirty: bool, // indicates if a page has been modified since it was read
    removed: bool, // indicates if a page has been removed from the page table

    pub fn format(
        self: PageTableEntry,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("PageTableEntry(offset: {d}, dirty: {any}, removed: {any})", .{ self.offset, self.dirty, self.removed });
    }
};

pub const BufferManager = struct {
    page_directory: PageDirectory, // permanent, always present in memory
    master_root_page: PageBuffer, // permanent, always present in memory
    page_table: ArrayList(PageTableEntry), // contents get swapped in and out of memory
    allocator: Allocator,

    pub fn masterSchema() [5]DataType {
        const columns_array = [5]DataType{
            DataType.String,
            DataType.String,
            DataType.BigInt,
            DataType.String,
            DataType.String,
        };

        return columns_array;
    }

    pub fn init(allocator: Allocator, database_name: []const u8) !BufferManager {
        const page_directory = try PageDirectory.init(allocator, database_name);
        const master_root_page = try BufferManager.initMaster(allocator);
        const page_table = ArrayList(PageTableEntry).init(allocator);
        return BufferManager{
            .page_directory = page_directory,
            .master_root_page = master_root_page,
            .page_table = page_table,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BufferManager) void {
        self.page_directory.deinit();
        self.master_root_page.deinit();
        for (self.page_table.items) |entry| {
            entry.page.deinit();
        }
        self.page_table.deinit();
    }

    pub fn initMaster(allocator: Allocator) !PageBuffer {
        var page = try PageBuffer.init(allocator, MASTER_PAGE_SIZE);
        const data = BufferManager.getInitialMasterData();

        const columns_array = BufferManager.masterSchema();
        const columns_heap = try allocator.dupe(DataType, &columns_array);
        defer allocator.free(columns_heap);

        for (data) |row| {
            const slice = try allocator.alloc(CellValue, row.len);
            // defer {
            //     for (slice) |cell| {
            //         allocator.free(cell);
            //     }
            //     allocator.free(slice);
            // }
            defer allocator.free(slice);

            @memcpy(slice, &row);

            const tuple = try Tuple.create(
                allocator,
                columns_heap,
                slice,
            );
            // defer allocator.free(tuple);
            defer tuple.deinit();

            try page.insertTuple(tuple);
        }

        return page;
    }

    fn getInitialMasterData() [5][5]CellValue {
        const data = [5][5]CellValue{ .{
            CellValue{ .string_value = "sys" },
            CellValue{ .string_value = "dbstar_master" },
            CellValue{ .bigint_value = 1 },
            CellValue{ .string_value = "schema_name" },
            CellValue{ .string_value = "string" },
        }, .{
            CellValue{ .string_value = "sys" },
            CellValue{ .string_value = "dbstar_master" },
            CellValue{ .bigint_value = 1 },
            CellValue{ .string_value = "table_name" },
            CellValue{ .string_value = "string" },
        }, .{
            CellValue{ .string_value = "sys" },
            CellValue{ .string_value = "dbstar_master" },
            CellValue{ .bigint_value = 1 },
            CellValue{ .string_value = "column_id" },
            CellValue{ .string_value = "int" },
        }, .{
            CellValue{ .string_value = "sys" },
            CellValue{ .string_value = "dbstar_master" },
            CellValue{ .bigint_value = 1 },
            CellValue{ .string_value = "column_name" },
            CellValue{ .string_value = "string" },
        }, .{
            CellValue{ .string_value = "sys" },
            CellValue{ .string_value = "dbstar_master" },
            CellValue{ .bigint_value = 1 },
            CellValue{ .string_value = "column_datatype" },
            CellValue{ .string_value = "string" },
        } };

        return data;
    }

    pub fn flush(self: *BufferManager, file: File) !void {
        // first we write page header and master page
        try self.flushHeaderMasterPage(file);

        // then we write the rest of the pages at their correct offset
        // if a page is not on disk, it will be added to the end of the file

        for (self.page_table.items) |*entry| {
            if (entry.dirty) {
                const page_bytes = entry.page.bytes;
                try file.pwriteAll(page_bytes, @intCast(entry.offset));
                entry.dirty = false;
                continue;
            } else {
                // if the page is not dirty, we don't need to write it to disk
                // we can just free the memory and remove it from the slice
                entry.page.deinit();
                entry.removed = true;
            }
        }

        for (self.page_table.items, 0..) |entry, i| {
            if (entry.removed) {
                _ = self.page_table.orderedRemove(i);
            }
        }
    }

    fn flushHeaderMasterPage(self: *BufferManager, file: File) !void {
        // first we write the page directory
        const page_directory_bytes = try self.page_directory.serialize();
        defer self.allocator.free(page_directory_bytes);
        try file.pwriteAll(page_directory_bytes, 0);

        // then we write the master page
        const master_root_page_bytes = self.master_root_page.bytes;
        try file.pwriteAll(master_root_page_bytes, MASTER_PAGE_START);
    }

    pub fn updateMaster(
        self: *BufferManager,
        schema: []Column,
        schema_name: []const u8,
        table_name: []const u8,
        root_page: i64,
    ) !void {

        // for each column in the schema, we need to add a row to the master page

        for (schema) |column| {
            const master_schema = BufferManager.masterSchema();
            const data = [5]CellValue{
                CellValue{ .string_value = schema_name },
                CellValue{ .string_value = table_name },
                CellValue{ .bigint_value = root_page },
                CellValue{ .string_value = column.name },
                CellValue{ .string_value = column.datatypeAsString() },
            };
            const data_slice = try self.allocator.dupe(CellValue, &data);
            defer self.allocator.free(data_slice);

            const master_schema_heap = try self.allocator.dupe(DataType, &master_schema);
            defer self.allocator.free(master_schema_heap);

            // const cell_values = try self.allocator.dupe(CellValue, &data);
            // defer self.allocator.free(cell_values);

            const tuple = try Tuple.create(
                self.allocator,
                master_schema_heap,
                data_slice,
            );
            defer tuple.deinit();

            try self.master_root_page.insertTuple(tuple);
        }
    }

    pub fn addPage(self: *BufferManager, page: PageBuffer) !u64 {
        const new_offset = try self.page_directory.getNextOffset();

        const entry = PageTableEntry{
            .offset = @intCast(new_offset),
            .page = page,
            .dirty = true,
            .removed = false,
        };
        try self.page_table.append(entry);
        return new_offset;
    }
};

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
    // var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    // defer arena.deinit();
    // const allocator = arena.allocator();

    const allocator = std.testing.allocator;
    const file = try std.fs.cwd().createFile("test.db", .{ .read = true, .truncate = true });

    var buffer_manager = try BufferManager.init(allocator, "urmom69");
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

test "flushHeaderMasterPage" {
    const allocator = std.testing.allocator;
    var buffer_manager = try BufferManager.init(allocator, "urmom69");
    const file = try std.fs.cwd().createFile("test.db", .{ .read = true, .truncate = false });

    defer buffer_manager.deinit();
    defer file.close();

    try buffer_manager.flushHeaderMasterPage(file);
}

test "updateMaster" {
    const allocator = std.testing.allocator;
    var buffer_manager = try BufferManager.init(allocator, "urmom69");
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

    var buffer_manager = try BufferManager.init(allocator, "urmom69");
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
