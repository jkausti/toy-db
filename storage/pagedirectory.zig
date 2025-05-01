const std = @import("std");
const print = std.debug.print;
const tst = std.testing;
const Allocator = std.mem.Allocator;
const PageBuffer = @import("page.zig").PageBuffer;
const assert = std.debug.assert;
const AutoHashMap = std.AutoHashMap;

const Tuple = @import("tuple.zig").Tuple;
const DataType = @import("column.zig").DataType;
const CellValue = @import("cell.zig").CellValue;

/// PageDirectory is the first page of the database file.
///
/// The implementation just wraps the page and adds
/// Database header specific things to the front.
///
/// The size is static at 8096 bytes for simplicity.
///
///
const SIGNATURE_LENGTH = 7;
const MAX_DB_NAME_LENGTH = 32;
pub const FIRST_PAGE_SIZE = 8192;
const NORMAL_PAGE_SIZE = 4096;

const PageDirError = error{
    OutOfRange,
    InvalidBufferLength,
    NoPageFound,
};

/// special first page that holds db metadata + a normal page
pub const PageDirectory = struct {
    metadata: DbMetadata,
    page: PageBuffer,
    allocator: Allocator,

    pub fn getSchema() ![]DataType {
        var schema = [_]DataType{ DataType.Int, DataType.BigInt };
        return @as([]DataType, &schema);
    }

    /// only called when a database is created, otherwise it is constructed
    /// with the deserialize method
    pub fn init(allocator: Allocator, db_name: []const u8) !PageDirectory {

        // metadata.* = DbMetadata{
        //     .signature = "dbstar2",
        //     .db_name = db_name,
        //     .page_count = 2,
        // };
        const metadata = try DbMetadata.init(
            allocator,
            "dbstar2",
            db_name,
        );

        var page = try PageBuffer.init(allocator, @intCast(FIRST_PAGE_SIZE - DbMetadata.sizeOnDisk()));

        // insert a row for the first page manually trough the PageBuffer API
        const first_page_tuple = try PageDirectory.createPageDirEntryTuple(allocator, 0, 0);
        const second_page_tuple = try PageDirectory.createPageDirEntryTuple(allocator, 1, FIRST_PAGE_SIZE);
        defer first_page_tuple.deinit();
        defer second_page_tuple.deinit();

        try page.insertTuple(first_page_tuple);
        try page.insertTuple(second_page_tuple);

        return PageDirectory{
            .metadata = metadata,
            .page = page,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *PageDirectory) void {
        self.page.deinit();
        self.metadata.deinit(self.allocator);
    }

    pub fn serialize(self: PageDirectory) ![]u8 {
        const metadata_buf = try self.metadata.serialize(self.allocator);
        defer self.allocator.free(metadata_buf);
        const page_buf = self.page.bytes;
        const total_size = metadata_buf.len + page_buf.len;
        const dir_buf = try self.allocator.alloc(u8, total_size);

        @memcpy(dir_buf[0..DbMetadata.sizeOnDisk()], metadata_buf);
        @memcpy(dir_buf[DbMetadata.sizeOnDisk() .. DbMetadata.sizeOnDisk() + page_buf.len], page_buf);
        return dir_buf;
    }

    pub fn deserialize(allocator: Allocator, buf: []u8) !PageDirectory {
        // const metadata = try allocator.create(DbMetadata);
        const metadata = try DbMetadata.deserialize(allocator, buf[0..DbMetadata.sizeOnDisk()]);
        const page_bytes = try allocator.alloc(u8, FIRST_PAGE_SIZE - DbMetadata.sizeOnDisk());
        @memcpy(page_bytes, buf[DbMetadata.sizeOnDisk()..]);
        const page = PageBuffer{ .allocator = allocator, .bytes = page_bytes };

        return PageDirectory{
            .metadata = metadata,
            .page = page,
            .allocator = allocator,
        };
    }

    fn createPageDirEntryTuple(allocator: Allocator, page_id: u32, offset: usize) !Tuple {
        var columns = try PageDirectory.getSchema();

        var data = [_]CellValue{
            CellValue{ .int_value = @intCast(page_id) },
            CellValue{ .bigint_value = @intCast(offset) },
        };
        return try Tuple.create(
            allocator,
            @as([]DataType, columns[0..]),
            @as([]CellValue, data[0..]),
        );
    }

    pub fn insertPageDirEntry(self: *PageDirectory, page_id: u32, offset: u64) !void {
        const pagedir_tuple = try PageDirectory.createPageDirEntryTuple(
            self.allocator,
            page_id,
            @intCast(offset),
        );
        defer pagedir_tuple.deinit();

        try self.page.insertTuple(pagedir_tuple);
    }

    pub fn getOffset(self: *PageDirectory, page_id: u32) !u64 {
        const columns = try PageDirectory.getSchema();
        const tuples = try self.page.getTuples(columns);
        defer self.allocator.free(tuples);
        defer {
            for (tuples) |tuple| {
                tuple.deinit();
            }
        }

        for (tuples) |tuple| {
            const page_id_cell = tuple.data[0];
            const offset_cell = tuple.data[1];
            const unpacked_page_id: u32 = switch (page_id_cell) {
                .int_value => |val| @intCast(val),
                else => {
                    unreachable;
                },
            };

            if (unpacked_page_id == page_id) {
                const offset: u64 = switch (offset_cell) {
                    .bigint_value => |val| @intCast(val),
                    else => {
                        unreachable;
                    },
                };
                return @intCast(offset);
            } else {
                continue;
            }
        }
        return PageDirError.NoPageFound;
    }

    pub fn fillPageMap(self: *PageDirectory, map_to_fill: *AutoHashMap(i32, i64)) !void {
        // gets all data from the pagedirectory page and creates a hashmap
        // with page_id -> offset
        // const id_offset_map = try AutoHashMap(i32, i64).init(self.allocator);
        const columns = try PageDirectory.getSchema();

        const tuples = try self.page.getTuples(columns);
        defer self.allocator.free(tuples);

        for (tuples) |tuple| {
            const page_id_cell = tuple.data[0];
            const offset_cell = tuple.data[1];
            const page_id: i32 = switch (page_id_cell) {
                .int_value => |val| val,
                else => {
                    unreachable;
                },
            };
            const offset: i64 = switch (offset_cell) {
                .bigint_value => |val| val,
                else => {
                    unreachable;
                },
            };
            try map_to_fill.put(page_id, offset);
            tuple.deinit();
        }
    }

    pub fn getNextOffset(self: *PageDirectory) !u64 {
        const columns = try PageDirectory.getSchema();
        const tuples = try self.page.getTuples(columns);
        defer self.allocator.free(tuples);
        defer {
            for (tuples) |tuple| {
                tuple.deinit();
            }
        }

        var max_offset: u64 = 0;
        for (tuples) |tuple| {
            const offset_cell = tuple.data[1];
            const offset: u64 = switch (offset_cell) {
                .bigint_value => |val| @intCast(val),
                else => {
                    unreachable;
                },
            };
            if (offset > max_offset) {
                max_offset = offset;
            }
        }

        return max_offset + NORMAL_PAGE_SIZE;
    }
};

pub const DbMetadata = struct {
    signature: []const u8,
    db_name: []const u8,
    page_count: u32,

    pub fn sizeOnDisk() u32 {
        return SIGNATURE_LENGTH + MAX_DB_NAME_LENGTH + 4 + 1;
    }

    pub fn init(allocator: Allocator, signature: []const u8, db_name: []const u8) !DbMetadata {
        if (signature.len != SIGNATURE_LENGTH) {
            return PageDirError.OutOfRange;
        }
        if (db_name.len > MAX_DB_NAME_LENGTH) {
            return PageDirError.OutOfRange;
        }

        const signature_bytes = try allocator.alloc(u8, signature.len);
        @memcpy(signature_bytes[0..signature.len], signature);

        const db_name_bytes = try allocator.alloc(u8, db_name.len);
        @memcpy(db_name_bytes[0..db_name.len], db_name);

        return DbMetadata{
            .signature = signature_bytes,
            .db_name = db_name_bytes,
            .page_count = 2,
        };
    }

    pub fn deinit(self: *DbMetadata, allocator: Allocator) void {
        allocator.free(self.signature);
        allocator.free(self.db_name);
    }

    pub fn serialize(self: DbMetadata, allocator: Allocator) ![]u8 {
        const buf = try allocator.alloc(u8, DbMetadata.sizeOnDisk());
        @memset(buf, 0);
        var offset: usize = 0;

        // write signature to the beginning
        @memcpy(buf[0..SIGNATURE_LENGTH], self.signature);
        offset = SIGNATURE_LENGTH;

        // write db_name length (1 byte) and db_name (max 31 bytes)
        const db_name_len: u8 = @intCast(self.db_name.len);
        if (db_name_len > 31) {
            return PageDirError.OutOfRange;
        }
        // @memcpy(buf[offset .. offset + 1], db_name_len);
        std.mem.writeInt(
            u8,
            @as(*[1]u8, @ptrCast(buf[offset .. offset + 1])),
            db_name_len,
            .little,
        );
        offset += 1;
        @memset(buf[offset .. offset + 31], 0);
        @memcpy(buf[offset .. offset + db_name_len], self.db_name);
        offset += 31;

        // write page_count
        const page_count_size = 4;
        std.mem.writeInt(
            u32,
            @as(*[page_count_size]u8, @ptrCast(buf[offset .. offset + page_count_size])),
            self.page_count,
            .little,
        );
        offset += page_count_size;

        return buf;
    }

    pub fn deserialize(allocator: Allocator, buf: []const u8) !DbMetadata {
        if (buf.len != DbMetadata.sizeOnDisk()) {
            return PageDirError.InvalidBufferLength;
        }

        const signature_bytes = try allocator.alloc(u8, SIGNATURE_LENGTH);

        var offset: usize = 0;
        // const signature = buf[offset..SIGNATURE_LENGTH];
        @memcpy(signature_bytes[0..SIGNATURE_LENGTH], buf[offset..SIGNATURE_LENGTH]);
        offset += SIGNATURE_LENGTH;

        // read db_name length and db_name
        const db_name_len = std.mem.readInt(
            u8,
            @as(*const [1]u8, @ptrCast(buf[offset .. offset + 1])),
            .little,
        );
        offset += 1;

        const dbname_bytes = try allocator.alloc(u8, db_name_len);
        @memcpy(dbname_bytes[0..db_name_len], buf[offset .. offset + db_name_len]);
        offset += 31;

        // read page_count
        const page_count = std.mem.readInt(
            u32,
            @as(*const [4]u8, @ptrCast(buf[offset .. offset + 4])),
            .little,
        );
        offset += 4;

        const metadata = DbMetadata{
            .signature = signature_bytes,
            .db_name = dbname_bytes,
            .page_count = page_count,
        };
        return metadata;
    }

    pub fn format(self: DbMetadata, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("DbMetadata{{\n", .{});
        try writer.print("\tsignature: {s}\n", .{self.signature});
        try writer.print("\tdb_name: {s}\n", .{self.db_name});
        try writer.print("\tpage_count: {d}\n", .{self.page_count});
        try writer.print("}}\n", .{});
    }
};
