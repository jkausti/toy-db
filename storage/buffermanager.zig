const std = @import("std");
const tst = std.testing;
const print = std.debug.print;
const ArrayList = std.ArrayList;
const File = std.fs.File;
const PageDirectory = @import("pagedirectory.zig").PageDirectory;
const DbMetadata = @import("pagedirectory.zig").DbMetadata;
const PageBuffer = @import("page.zig").PageBuffer;
const DataType = @import("column.zig").DataType;
const Column = @import("column.zig").Column;
const CellValue = @import("cell.zig").CellValue;
const Tuple = @import("tuple.zig").Tuple;
const Allocator = std.mem.Allocator;

const FIRST_PAGE_SIZE = @import("pagedirectory.zig").FIRST_PAGE_SIZE;
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

    pub fn init(allocator: Allocator, database_name: ?[]const u8, file_handle: ?File) !BufferManager {
        // const page_directory = try allocator.create(PageDirectory);
        // const master_root_page = try allocator.create(PageBuffer);
        // defer allocator.destroy(page_directory);
        // defer allocator.destroy(master_root_page);
        var page_directory: PageDirectory = undefined;
        var master_root_page: PageBuffer = undefined;

        if (file_handle != null) {
            var buffer = try allocator.alloc(u8, FIRST_PAGE_SIZE + MASTER_PAGE_SIZE);
            defer allocator.free(buffer);

            _ = try file_handle.?.readAll(buffer);

            page_directory = try PageDirectory.deserialize(allocator, buffer[0..FIRST_PAGE_SIZE]);

            const page_buffer = try allocator.alloc(u8, MASTER_PAGE_SIZE);
            @memcpy(page_buffer, buffer[FIRST_PAGE_SIZE .. FIRST_PAGE_SIZE + MASTER_PAGE_SIZE]);
            master_root_page = PageBuffer{
                .allocator = allocator,
                .bytes = page_buffer,
            };
        } else {
            page_directory = try PageDirectory.init(allocator, database_name.?);
            master_root_page = try BufferManager.initMaster(allocator);
        }
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
