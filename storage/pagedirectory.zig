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
const FIRST_PAGE_SIZE = 8192;
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
        const metadata = DbMetadata{
            .signature = "dbstar2",
            .db_name = db_name,
            .page_count = 2,
        };
        var page = try PageBuffer.init(allocator, @intCast(FIRST_PAGE_SIZE - DbMetadata.sizeOnDisk()));

        // insert a row for the first page manually trough the PageBuffer API
        const first_page_tuple = try PageDirectory.createPageDirEntryTuple(allocator, 1, 0);
        const second_page_tuple = try PageDirectory.createPageDirEntryTuple(allocator, 2, FIRST_PAGE_SIZE);
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
        const metadata = try DbMetadata.deserialize(buf[0..DbMetadata.sizeOnDisk()]);
        const page = PageBuffer{ .allocator = allocator, .bytes = buf[DbMetadata.sizeOnDisk()..] };
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

    pub fn insertPageDirEntry(self: *PageDirectory, page_id: u32, offset: usize) !void {
        const pagedir_tuple = try PageDirectory.createPageDirEntryTuple(self.allocator, page_id, offset);
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

const DbMetadata = struct {
    signature: []const u8,
    db_name: []const u8,
    page_count: u32,

    pub fn sizeOnDisk() u32 {
        return SIGNATURE_LENGTH + MAX_DB_NAME_LENGTH + 4 + 1;
    }

    pub fn serialize(self: DbMetadata, allocator: Allocator) ![]u8 {
        const buf = try allocator.alloc(u8, DbMetadata.sizeOnDisk());
        @memset(buf, 0);
        var offset: usize = 0;

        // write signature to the beginning
        @memcpy(buf[0..self.signature.len], self.signature);
        offset = self.signature.len;

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

    pub fn deserialize(buf: []const u8) !DbMetadata {
        if (buf.len != DbMetadata.sizeOnDisk()) {
            return PageDirError.InvalidBufferLength;
        }

        var offset: usize = 0;
        const signature = buf[offset..SIGNATURE_LENGTH];
        offset += SIGNATURE_LENGTH;

        // read db_name length and db_name
        const db_name_len = std.mem.readInt(
            u8,
            @as(*const [1]u8, @ptrCast(buf[offset .. offset + 1])),
            .little,
        );
        offset += 1;
        const db_name = buf[offset .. offset + db_name_len];
        offset += 31;

        // read page_count
        const page_count = std.mem.readInt(
            u32,
            @as(*const [4]u8, @ptrCast(buf[offset .. offset + 4])),
            .little,
        );
        offset += 4;

        return DbMetadata{
            .signature = signature,
            .db_name = db_name,
            .page_count = page_count,
        };
    }
};

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

    const page_1_offset = try page_dir.getOffset(1);
    const page_2_offset = try page_dir.getOffset(2);

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

    const offset1 = map.get(1);
    try tst.expect(offset1.? == 0);

    const offset2 = map.get(2);
    try tst.expect(offset2.? == 8192);
}
