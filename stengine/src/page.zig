const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const tst = std.testing;
const assert = std.debug.assert;

const PageError = error{InvalidBufferLength};

// pub const FreeSpace = struct {
//     start: u64,
//     end: u64,
//
//     pub fn toBytes(self: FreeSpace, allocator: Allocator) ![]u8 {
//         const byte_arr = try allocator.alloc(u8, 4);
//         std.mem.writeInt(u16, byte_arr[0..2], self.start, .little);
//         std.mem.writeInt(u16, byte_arr[2..4], self.end, .little);
//
//         return byte_arr;
//     }
//
//     pub fn fromBytes(bytes: []u8) !FreeSpace {
//         if (bytes.len != 4) {
//             return PageError.InvalidBufferLength;
//         }
//
//         return FreeSpace{
//             .start = std.mem.readInt(u16, bytes[0..2], .little),
//             .end = std.mem.readInt(u16, bytes[2..4], .little),
//         };
//     }
// };

pub const PageHeader = struct {
    slot_array_size: u64,
    last_used_offset: u64,
    free_space: u64, // bytes

    pub fn init(page_size: u64) PageHeader {
        // const free_space = try allocator.alloc(FreeSpace, 1);
        // free_space[0].start = (@sizeOf(PageHeader) - 1);
        // free_space[0].end = page_size - 1;

        return PageHeader{
            .slot_array_size = 0,
            .last_used_offset = page_size - 1,
            .free_space = page_size - @sizeOf(PageHeader),
        };
    }

    pub fn toBytes(self: PageHeader, allocator: Allocator) ![]u8 {
        var buffer = ArrayList(u8).init(allocator);
        defer buffer.deinit();

        // const free_space_bytes = try self.free_space.toBytes(allocator);
        try buffer.appendSlice(std.mem.asBytes(&self.slot_array_size));
        try buffer.appendSlice(std.mem.asBytes(&self.last_used_offset));
        try buffer.appendSlice(std.mem.asBytes(&self.free_space));
        return try buffer.toOwnedSlice();
    }

    pub fn fromBytes(bytes: []u8) PageHeader {
        const slot_array_size = std.mem.readInt(u64, bytes[0..8], .little);
        const last_used_offset = std.mem.readInt(u64, bytes[8..16], .little);
        const free_space = std.mem.readInt(u64, bytes[16..24], .little);

        return PageHeader{
            .slot_array_size = slot_array_size,
            .last_used_offset = last_used_offset,
            .free_space = free_space,
        };
    }
};

pub const SlotArray = struct {
    slot_offsets: []u16,
    allocator: Allocator,

    pub fn init(allocator: Allocator) !SlotArray {
        const initial_size = 0;
        const slots = try allocator.alloc(u16, initial_size);
        return SlotArray{ .slot_offsets = slots, .allocator = allocator };
    }

    pub fn insert(self: *SlotArray, offset: u16) !void {
        const slot_arr_size = self.slot_offsets.len;
        var last_value: ?u16 = undefined;

        if (slot_arr_size > 0) {
            last_value = self.slot_offsets[slot_arr_size - 1];
        } else {
            last_value = null;
        }

        const new_slot_array = try self.allocator.realloc(
            self.slot_offsets,
            self.slot_offsets.len + 1,
        );

        new_slot_array[slot_arr_size] = offset;
        self.slot_offsets = new_slot_array;

        if (last_value != null) {
            assert(new_slot_array[self.slot_offsets.len - 2] == last_value);
        }
    }

    pub fn deinit(self: *SlotArray) void {
        self.allocator.free(self.slot_offsets);
    }

    pub fn serialize(self: SlotArray) ![]u8 {
        var byte_arr: []u8 = try self.allocator.alloc(u8, self.slot_offsets.len * 2);
        var step_start = 0;
        var step_end = 2;

        for (self.slot_array) |slot_arr_offset| {
            // const offset_bytes = std.mem.toBytes(&slot_arr_offset);
            // byte_arr[step_start..offset_bytes.len] = offset_bytes;
            // const offset_alloced = self.allocator.create(u16);
            // offset_alloced.* = slot_arr_offset;
            std.mem.writeInt(
                u16,
                byte_arr[step_start..step_end],
                slot_arr_offset,
                .little,
            );
            step_start += 2;
            step_end += 2;
        }

        return byte_arr;
    }
};

/// Slotted page. Used to store a PageHeader and records.
pub const Page = struct {
    buffer: BufferWithHeader,

    pub fn init(allocator: Allocator, page_size: u64) !Page {
        const buffer = try BufferWithHeader.init(allocator, page_size);
        return Page{ .buffer = buffer };
    }

    // pub fn serialize(self: *Page, allocator: Allocator) ![]u8 {
    //     const header = self.buffer.getHeader();
    //     const header_bytes: []u8 = try header.toBytes(allocator);
    //
    //     // only get initialized memory
    //     const content_size = self.buffer.content.len;
    //     const content = self.buffer.content[header.size..content_size];
    //     defer buffer.deinit();
    //
    //     try buffer.appendSlice(header_bytes);
    //     try buffer.appendSlice(content);
    //     return try buffer.toOwnedSlice();
    // }

    pub fn getHeader(self: *Page) PageHeader {
        return self.buffer.getHeader();
    }

    // pub fn insert(self: *Page, record: []u8) void {
    // Tries to insert a record into the page if there is enough space.
    // 1. Reads the header to determine if there is space.
    // 2. If there is space, inserts the record and updates header.
    // 3. If there is no space, returns an error.

    //     const header = self.buffer.getHeader();
    //
    //     for (header.free_space) |space| {
    //         // just insert in first available space
    //         if (space.len > record.len) {
    //             // okay to insert
    //             const insert_offset = space.end - record.len;
    //             // const content = self.buffer.content;
    //             content[insert_offset..record.len] = record;
    //
    //             self.buffer.setContent(&content);
    //
    //         }
    //     }
    // }
    //
    // pub fn update(self: *Page) void {
    // TODO
    // }

    // pub fn delete(self: *Page) void {
    // TODO
    // }
};

pub const BufferWithHeader = struct {
    header: []u8,
    content: []u8,
    size: u64,
    allocator: Allocator,

    pub fn init(allocator: Allocator, page_size: u64) !BufferWithHeader {

        // initiating this will also initiate a PageHeader

        const header_size = @sizeOf(PageHeader);
        const content_mem = try allocator.alloc(u8, page_size - header_size);

        const page_header = PageHeader.init(page_size);
        const page_header_bytes = try page_header.toBytes(allocator);
        return BufferWithHeader{
            .header = page_header_bytes,
            .content = content_mem,
            .size = page_size,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BufferWithHeader) void {
        self.allocator.free(self.header);
        self.allocator.free(self.content);
    }

    pub fn setHeader(self: *BufferWithHeader, header: PageHeader) !void {
        const header_bytes: []u8 = try header.toBytes(self.allocator);
        @memcpy(self.header, header_bytes);
        self.allocator.free(header_bytes);
    }

    pub fn getHeader(self: *BufferWithHeader) PageHeader {
        const header = PageHeader.fromBytes(self.header);
        return header;
    }

    pub fn getContent(self: *BufferWithHeader) []u8 {
        return self.content;
    }

    pub fn setContent(self: *BufferWithHeader, content: []u8, page_size: u64) []u8 {
        const new_content = self.allocator.alloc(u8, page_size - @sizeOf(PageHeader));
        @memcpy(new_content, content);
        self.allocator.free(self.content);
        self.content = new_content;
    }
};

test "bufferWithHeader_mem_leak" {
    const allocator = tst.allocator;
    const PAGE_SIZE: u64 = 4096;

    var buffer = try BufferWithHeader.init(allocator, PAGE_SIZE);
    defer buffer.deinit();
}

test "bufferWithHeader_setgetHeader" {
    const allocator = tst.allocator;
    const PAGE_SIZE: u64 = 4096;

    var buffer = try BufferWithHeader.init(allocator, PAGE_SIZE);
    defer buffer.deinit();

    const header = PageHeader.init(PAGE_SIZE);
    try buffer.setHeader(header);

    const header_from_buffer = buffer.getHeader();
    try tst.expect(header_from_buffer.slot_array_size == 0);
    try tst.expect(header_from_buffer.last_used_offset == (PAGE_SIZE - 1));
    try tst.expect(header_from_buffer.free_space == (PAGE_SIZE - @sizeOf(PageHeader)));
}

test "SlotArray" {
    const allocator = tst.allocator;
    var slot_array = try SlotArray.init(allocator);
    defer slot_array.deinit();

    try slot_array.insert(0);
    try slot_array.insert(2);
    try slot_array.insert(4);

    try tst.expect(slot_array.slot_offsets.len == 3);
    try tst.expect(slot_array.slot_offsets[2] == 4);
}
