const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const tst = std.testing;
const assert = std.debug.assert;
const Tuple = @import("tuple.zig").Tuple;
const DataType = @import("column.zig").DataType;
const CellValue = @import("cell.zig").CellValue;

const PageError = error{ InvalidBufferLength, NotEnoughSpace, EmptyPage };

/// Header that resides at the beginning of a page.
/// Contains metadata about the page necessary to perform operations.
///  - slot_array_size: Size of the slot array (in bytes, since one slot = 2 bytes bc u16).
///  - last_used_offset: Offset of the last inserted record in the page.
///  - free_space: Amount of free space in the page.
///      Generally, last_used_offset - @sizeOf(PageHeader) - slot_array_size.
///
pub const PageHeader = struct {
    slot_array_size: u16,
    last_used_offset: u16,
    free_space: u16, // bytes
    page_size: u16,

    pub fn init(page_size: u16) PageHeader {
        return PageHeader{
            .slot_array_size = 0,
            .last_used_offset = page_size,
            .free_space = page_size - @sizeOf(PageHeader),
            .page_size = page_size,
        };
    }

    /// Serializes the PageHeader into a byte array.
    ///
    pub fn serialize(self: PageHeader) [@sizeOf(PageHeader)]u8 {
        var buffer = [_]u8{0} ** @sizeOf(PageHeader);

        std.mem.writeInt(u16, buffer[0..2], self.slot_array_size, .little);
        std.mem.writeInt(u16, buffer[2..4], self.last_used_offset, .little);
        std.mem.writeInt(u16, buffer[4..6], self.free_space, .little);
        std.mem.writeInt(u16, buffer[6..8], self.page_size, .little);

        return buffer;
    }

    /// Deserializes a byte array into a PageHeader.
    pub fn deserialize(bytes: []u8) PageHeader {
        const slot_array_size = std.mem.readInt(u16, bytes[0..2], .little);
        const last_used_offset = std.mem.readInt(u16, bytes[2..4], .little);
        const free_space = std.mem.readInt(u16, bytes[4..6], .little);
        const page_size = std.mem.readInt(u16, bytes[6..8], .little);

        return PageHeader{
            .slot_array_size = slot_array_size,
            .last_used_offset = last_used_offset,
            .free_space = free_space,
            .page_size = page_size,
        };
    }
};

pub const SlotArray = struct {
    slot_offsets: ?[]u16,
    allocator: Allocator,

    pub fn init(allocator: Allocator) !SlotArray {
        return SlotArray{ .slot_offsets = null, .allocator = allocator };
    }

    pub fn deinit(self: *SlotArray) void {
        self.allocator.free(self.slot_offsets.?);
    }

    /// Inserting a slot offset into the slot array.
    /// Offset parameter is the offset of the start of the
    /// inserted record.
    pub fn insert(self: *SlotArray, offset: u16) !void {
        var last_value: ?u16 = undefined;
        var new_slot_array: []u16 = undefined;

        if (self.slot_offsets != null) {
            last_value = self.slot_offsets.?[self.slot_offsets.?.len - 1];
            new_slot_array = try self.allocator.alloc(
                u16,
                self.slot_offsets.?.len + 1,
            );

            @memcpy(
                new_slot_array[0..self.slot_offsets.?.len],
                self.slot_offsets.?,
            );
            self.allocator.free(self.slot_offsets.?);
        } else {
            last_value = null;
            new_slot_array = try self.allocator.alloc(
                u16,
                1,
            );
        }

        new_slot_array[new_slot_array.len - 1] = offset;
        self.slot_offsets = new_slot_array;

        if (last_value != null) {
            assert(new_slot_array[self.slot_offsets.?.len - 2] == last_value);
        }
    }

    /// returns the slot array as a byte array.
    /// The slot array is serialized as a byte array of u16 values.
    /// If the slot array is empty, it returns null.
    pub fn serialize(self: SlotArray) !?[]u8 {
        if (self.slot_offsets == null) {
            return null;
        }

        var byte_arr = try self.allocator.alloc(u8, self.slot_offsets.?.len * 2);
        var step_start: usize = 0;
        var step_end: usize = 2;

        for (self.slot_offsets.?) |slot_arr_offset| {
            const fixed_size_memory_space = byte_arr[step_start..step_end];
            std.debug.assert(fixed_size_memory_space.len == 2);

            std.mem.writeInt(
                u16,
                @as(*[2]u8, @ptrCast(byte_arr[step_start..step_end])),
                slot_arr_offset,
                .little,
            );
            step_start += 2;
            step_end += 2;
        }

        return byte_arr;
    }

    pub fn deserialize(allocator: Allocator, byte_array: []u8) !SlotArray {
        if (byte_array.len == 0) {
            // not sure if this should return an error instead
            return SlotArray{ .slot_offsets = null, .allocator = allocator };
        }

        const slot_array_len = byte_array.len / 2;
        var slot_offsets: []u16 = try allocator.alloc(u16, slot_array_len);
        var step_start: usize = 0;
        var step_end: usize = 2;

        for (0..slot_array_len) |i| {
            const fixed_size_memory_space = byte_array[step_start..step_end];
            std.debug.assert(fixed_size_memory_space.len == 2);

            const slot_offset = std.mem.readInt(
                u16,
                @as(*const [2]u8, @ptrCast(fixed_size_memory_space)),
                .little,
            );
            slot_offsets[i] = slot_offset;
            step_start += 2;
            step_end += 2;
        }

        return SlotArray{ .slot_offsets = slot_offsets, .allocator = allocator };
    }
};

// pub const Page = struct {
//     header: PageHeader,
//     slot_array: SlotArray,
//     tuples: ?[]Tuple,
//     allocator: Allocator,
//
//     pub fn init(page_size: u16, allocator: Allocator) !Page {
//         return Page{
//             .header = PageHeader.init(page_size),
//             .slot_array = try SlotArray.init(allocator),
//             .tuples = null,
//             .allocator = allocator,
//         };
//     }
//
//     pub fn deinit(self: Page) void {
//         self.slot_array.deinit();
//         self.allocator.free(self.tuples.?);
//     }
//
//     fn serializeTuples(self: Page) ![]u8 {
//         if (self.tuples == null) {
//             return;
//         }
//
//         var buffer = ArrayList(u8).init(self.allocator);
//         defer buffer.deinit();
//
//         for (self.tuples.?) |tuple| {
//             const tuple_bytes = try tuple.serialize();
//             try buffer.appendSlice(tuple_bytes);
//         }
//     }
//
//     pub fn serialize(self: Page) ![]u8 {
//         var buffer = ArrayList(u8).init(self.allocator);
//         defer buffer.deinit();
//
//         const header_bytes = self.header.serialize();
//         const slot_array_bytes = try self.slot_array.serialize();
//         const tuples_bytes = try self.tuples.serialize();
//
//         try buffer.appendSlice(&header_bytes);
//         try buffer.appendSlice(slot_array_bytes);
//         try buffer.appendSlice(tuples_bytes);
//
//         return try buffer.toOwnedSlice();
//     }
// };

pub const PageBuffer = struct {
    bytes: []u8,
    allocator: Allocator,

    pub fn init(allocator: Allocator, page_size: usize) !PageBuffer {
        const bytes = try allocator.alloc(u8, page_size);
        @memset(bytes, 0); // initialize the page with 0s

        // set header default data
        const header = PageHeader.init(@intCast(page_size));
        const header_bytes = header.serialize();

        @memcpy(bytes[0..@sizeOf(PageHeader)], &header_bytes);

        return PageBuffer{ .bytes = bytes, .allocator = allocator };
    }

    pub fn deinit(self: PageBuffer) void {
        self.allocator.free(self.bytes);
    }

    pub fn insertTuple(self: *PageBuffer, tuple: Tuple) !void {
        // Tries to insert a record into the page if there is enough space.
        // 1. Reads the header to determine if there is space.
        // 2. If there is space, inserts the record and updates header.
        // 3. Updates the slot array
        // 3. If there is no space, returns an error.

        var header = try self.readHeader();

        var slot_array: SlotArray = undefined;
        if (header.slot_array_size == 0) {
            slot_array = try SlotArray.init(self.allocator);
        } else {
            slot_array = try self.readSlotArray();
        }

        const tuple_bytes = try tuple.serialize();
        defer self.allocator.free(tuple_bytes);

        // TODO: a new page should be allocated and linked to from the current page
        // if there is not enough space in the current page.
        if (header.free_space < tuple_bytes.len) {
            return PageError.NotEnoughSpace;
        }

        // calculate starting offset and insert into page
        const starting_offset: u16 = @intCast(header.last_used_offset - tuple_bytes.len);
        @memcpy(self.bytes[starting_offset..header.last_used_offset], tuple_bytes);

        // update header
        header.free_space -= @intCast(tuple_bytes.len);
        header.last_used_offset = @intCast(starting_offset);
        header.slot_array_size += 2;

        const header_bytes = header.serialize();
        @memcpy(self.bytes[0..@sizeOf(PageHeader)], &header_bytes);

        // update slot array

        defer slot_array.deinit();
        try slot_array.insert(@intCast(starting_offset));
        const slot_array_bytes = try slot_array.serialize();
        defer self.allocator.free(slot_array_bytes.?);

        @memcpy(
            self.bytes[@sizeOf(PageHeader) .. @sizeOf(PageHeader) + (header.slot_array_size)],
            slot_array_bytes.?,
        );
    }

    pub fn readHeader(self: PageBuffer) !PageHeader {
        const header_bytes = self.bytes[0..@sizeOf(PageHeader)];
        return PageHeader.deserialize(header_bytes);
    }

    pub fn readSlotArray(self: PageBuffer) !SlotArray {
        const header = try self.readHeader();
        const slot_array_bytes = self.bytes[@sizeOf(PageHeader) .. @sizeOf(PageHeader) + header.slot_array_size];
        return SlotArray.deserialize(self.allocator, slot_array_bytes);
    }

    pub fn getTuples(self: PageBuffer, columns: []DataType) ![]Tuple {
        const header = try self.readHeader();
        var slot_array = try self.readSlotArray();
        defer slot_array.deinit();

        var tuples = ArrayList(Tuple).init(self.allocator);
        defer tuples.deinit();

        var previous_offset: u32 = 0;
        for (slot_array.slot_offsets.?) |slot_offset| {
            var tuple: Tuple = undefined;
            if (previous_offset == 0) {
                // first slot
                tuple = try Tuple.deserialize(
                    self.allocator,
                    columns,
                    self.bytes[slot_offset..header.page_size],
                );
            } else {
                tuple = try Tuple.deserialize(
                    self.allocator,
                    columns,
                    self.bytes[slot_offset..previous_offset],
                );
            }
            try tuples.append(tuple);
            previous_offset = slot_offset;
            std.debug.assert(tuple.data.len > 0);
            std.debug.assert(tuple.columns.len > 0);
        }

        const tuple_slice = try tuples.toOwnedSlice();
        std.debug.assert(tuple_slice.len == slot_array.slot_offsets.?.len);
        return tuple_slice;
    }
};

test "SlotArray" {
    const allocator = tst.allocator;
    var slot_array = try SlotArray.init(allocator);
    defer slot_array.deinit();

    try slot_array.insert(0);
    try slot_array.insert(2);
    try slot_array.insert(4);

    try tst.expect(slot_array.slot_offsets.?.len == 3);
    try tst.expect(slot_array.slot_offsets.?[2] == 4);
}

test "serialize_SlotArray" {
    const allocator = tst.allocator;
    var slot_array = try SlotArray.init(allocator);
    defer slot_array.deinit();

    const null_serialized = try slot_array.serialize();
    try tst.expect(null_serialized == null);

    try slot_array.insert(0);
    try slot_array.insert(2);
    try slot_array.insert(99);

    const serialized = try slot_array.serialize();
    defer allocator.free(serialized.?);
    try tst.expect(serialized != null);
    try tst.expect(serialized.?.len == 6);

    var new_slot_array = try SlotArray.deserialize(allocator, serialized.?);
    defer new_slot_array.deinit();

    try tst.expect(new_slot_array.slot_offsets.?.len == 3);
    try tst.expect(new_slot_array.slot_offsets.?[2] == 99);
}

test "PageBuffer" {
    var log_allocator = std.heap.loggingAllocator(tst.allocator);
    const allocator = log_allocator.allocator();

    const PAGE_SIZE = 4096;

    var page_buffer = try PageBuffer.init(allocator, PAGE_SIZE);
    defer page_buffer.deinit();

    const columns_lit = [_]DataType{
        DataType.Int,
        DataType.String,
    };
    const columns = try allocator.dupe(DataType, &columns_lit);
    defer allocator.free(columns);

    const cells_lit = [_]CellValue{
        CellValue{ .int_value = 10 },
        CellValue{ .string_value = "hello world" },
    };
    const cells = try allocator.dupe(CellValue, &cells_lit);
    defer allocator.free(cells);

    const tuple = try Tuple.create(
        allocator,
        columns,
        cells,
    );
    defer tuple.deinit();

    try page_buffer.insertTuple(tuple);

    const header = try page_buffer.readHeader();
    var slot_array = try page_buffer.readSlotArray();
    defer slot_array.deinit();

    try tst.expect(header.free_space == PAGE_SIZE - @sizeOf(PageHeader) - 17);
    try tst.expect(header.slot_array_size == 2);
    try tst.expect(slot_array.slot_offsets.?.len == 1);
}

test "getTuples" {
    var log_allocator = std.heap.loggingAllocator(tst.allocator);
    const allocator = log_allocator.allocator();

    const PAGE_SIZE = 4096;

    var page_buffer = try PageBuffer.init(allocator, PAGE_SIZE);
    defer page_buffer.deinit();

    const columns_lit = [_]DataType{
        DataType.Int,
        DataType.String,
    };
    const columns = try allocator.dupe(DataType, &columns_lit);
    defer allocator.free(columns);

    const cells_lit = [_]CellValue{
        CellValue{ .int_value = 10 },
        CellValue{ .string_value = "hello world" },
    };
    const cells = try allocator.dupe(CellValue, &cells_lit);
    defer allocator.free(cells);

    const tuple = try Tuple.create(
        allocator,
        columns,
        cells,
    );
    defer tuple.deinit();

    try page_buffer.insertTuple(tuple);

    const tuples = try page_buffer.getTuples(columns);
    defer allocator.free(tuples);
    defer {
        for (tuples) |t| {
            t.deinit();
        }
    }

    try tst.expect(tuples.len == 1);
    try tst.expect(tuples[0].data.len == 2);
    try tst.expect(tuples[0].data[0].int_value == 10);
    try tst.expect(std.mem.eql(u8, tuples[0].data[1].string_value, "hello world"));
}
