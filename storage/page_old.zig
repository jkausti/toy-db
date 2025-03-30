// const std = @import("std");
// const print = std.debug.print;
// const Allocator = std.mem.Allocator;
// const ArrayList = std.ArrayList;
// const tst = std.testing;
// const assert = std.debug.assert;
// const DataType = @import("column.zig").DataType;
// const CellValue = @import("cell.zig").CellValue;
// const Tuple = @import("tuple.zig").Tuple;

// const PageError = error{ InvalidBufferLength, NotEnoughSpace };

// /// Header that resides at the beginning of a page.
// /// Contains metadata about the page necessary to perform operations.
// ///  - slot_array_size: Size of the slot array (in bytes, since one slot = 2 bytes bc u16).
// ///  - last_used_offset: Offset of the last inserted record in the page.
// ///  - free_space: Amount of free space in the page.
// ///      Generally, last_used_offset - @sizeOf(PageHeader) - slot_array_size.
// pub const PageHeader = struct {
//     slot_array_size: u16,
//     last_used_offset: u16,
//     free_space: u16, // bytes

//     pub fn init(page_size: u16) PageHeader {
//         return PageHeader{
//             .slot_array_size = 0,
//             .last_used_offset = page_size - @sizeOf(PageHeader),
//             .free_space = page_size - @sizeOf(PageHeader),
//         };
//     }

//     /// Serializes the PageHeader into a byte array.
//     pub fn serialize(self: PageHeader, allocator: Allocator) ![]u8 {
//         var buffer = ArrayList(u8).init(allocator);
//         defer buffer.deinit();

//         // const free_space_bytes = try self.free_space.serialize(allocator);
//         try buffer.appendSlice(std.mem.asBytes(&self.slot_array_size));
//         try buffer.appendSlice(std.mem.asBytes(&self.last_used_offset));
//         try buffer.appendSlice(std.mem.asBytes(&self.free_space));
//         return try buffer.toOwnedSlice();
//     }

//     /// Deserializes a byte array into a PageHeader.
//     pub fn deserialize(bytes: []u8) PageHeader {
//         const slot_array_size = std.mem.readInt(u16, bytes[0..2], .little);
//         const last_used_offset = std.mem.readInt(u16, bytes[2..4], .little);
//         const free_space = std.mem.readInt(u16, bytes[4..6], .little);

//         return PageHeader{
//             .slot_array_size = slot_array_size,
//             .last_used_offset = last_used_offset,
//             .free_space = free_space,
//         };
//     }
// };

// pub const SlotArray = struct {
//     slot_offsets: ?[]u16,
//     allocator: Allocator,

//     pub fn init(allocator: Allocator) !SlotArray {
//         return SlotArray{ .slot_offsets = null, .allocator = allocator };
//     }

//     /// Inserting a slot offset into the slot array.
//     /// Offset parameter is the offset of the start of the
//     /// inserted record.
//     pub fn insert(self: *SlotArray, offset: u16) !void {
//         var last_value: ?u16 = undefined;
//         var new_slot_array: []u16 = undefined;

//         if (self.slot_offsets != null) {
//             last_value = self.slot_offsets.?[self.slot_offsets.?.len - 1];
//             new_slot_array = try self.allocator.alloc(
//                 u16,
//                 self.slot_offsets.?.len + 1,
//             );

//             @memcpy(
//                 new_slot_array[0..self.slot_offsets.?.len],
//                 self.slot_offsets.?,
//             );
//             self.allocator.free(self.slot_offsets.?);
//         } else {
//             last_value = null;
//             new_slot_array = try self.allocator.alloc(
//                 u16,
//                 1,
//             );
//         }

//         new_slot_array[new_slot_array.len - 1] = offset;
//         self.slot_offsets = new_slot_array;

//         if (last_value != null) {
//             assert(new_slot_array[self.slot_offsets.?.len - 2] == last_value);
//         }
//     }

//     pub fn deinit(self: *SlotArray) void {
//         self.allocator.free(self.slot_offsets.?);
//     }

//     /// returns the slot array as a byte array.
//     /// The slot array is serialized as a byte array of u16 values.
//     /// If the slot array is empty, it returns null.
//     pub fn serialize(self: SlotArray) !?[]u8 {
//         if (self.slot_offsets == null) {
//             return null;
//         }

//         var byte_arr = try self.allocator.alloc(u8, self.slot_offsets.?.len * 2);
//         var step_start: usize = 0;
//         var step_end: usize = 2;

//         for (self.slot_offsets.?) |slot_arr_offset| {
//             const fixed_size_memory_space = byte_arr[step_start..step_end];
//             std.debug.assert(fixed_size_memory_space.len == 2);

//             std.mem.writeInt(
//                 u16,
//                 @as(*[2]u8, @ptrCast(byte_arr[step_start..step_end])),
//                 slot_arr_offset,
//                 .little,
//             );
//             step_start += 2;
//             step_end += 2;
//         }

//         return byte_arr;
//     }

//     pub fn deserialize(allocator: Allocator, byte_array: []u8) !SlotArray {
//         if (byte_array.len == 0) {
//             // not sure if this should return an error instead
//             return SlotArray{ .slot_offsets = null, .allocator = allocator };
//         }

//         const slot_array_len = byte_array.len / 2;
//         var slot_offsets: []u16 = try allocator.alloc(u16, slot_array_len);
//         var step_start: usize = 0;
//         var step_end: usize = 2;

//         for (0..slot_array_len) |i| {
//             const fixed_size_memory_space = byte_array[step_start..step_end];
//             std.debug.assert(fixed_size_memory_space.len == 2);

//             const slot_offset = std.mem.readInt(
//                 u16,
//                 @as(*const [2]u8, @ptrCast(fixed_size_memory_space)),
//                 .little,
//             );
//             slot_offsets[i] = slot_offset;
//             step_start += 2;
//             step_end += 2;
//         }

//         return SlotArray{ .slot_offsets = slot_offsets, .allocator = allocator };
//     }
// };

// /// Slotted page. Used to store a PageHeader and records.
// pub const Page = struct {
//     buffer: BufferWithHeader,
//     // overflow: ?Page,

//     pub fn init(allocator: Allocator, page_size: u16) !Page {
//         const buffer = try BufferWithHeader.init(allocator, page_size);
//         return Page{ .buffer = buffer };
//     }

//     pub fn deinit(self: *Page) void {
//         self.buffer.deinit();
//     }

//     pub fn deserialize(allocator: Allocator, buffer: []u8) !Page {
//         const new_buf = try allocator.alloc(u8, buffer.len);
//         @memcpy(new_buf, buffer);

//         const page_header = PageHeader.deserialize(new_buf[0..@sizeOf(PageHeader)]);
//         const page = Page.init(allocator, @intCast(new_buf.len));
//         _ = page.buffer.setHeader(new_buf[0..@sizeOf(PageHeader)], page_header);
//         _ = page.buffer.setContent(new_buf[@sizeOf(PageHeader)..new_buf.len]);

//         const buffer_with_header = BufferWithHeader{
//             .header = new_buf[0..@sizeOf(PageHeader)],
//             .content = new_buf[@sizeOf(PageHeader)..new_buf.len],
//             .size = @intCast(new_buf.len),
//             .allocator = allocator,
//         };

//         page.buffer = buffer_with_header;
//         return page;
//     }

//     pub fn serialize(self: Page, allocator: Allocator) ![]u8 {
//         const buf = try allocator.alloc(u8, self.buffer.size);
//         @memcpy(buf[0..self.buffer.header.len], self.buffer.header);
//         @memcpy(buf[self.buffer.header.len..self.buffer.size], self.buffer.content);
//         return buf;
//     }

//     // pub fn serialize(self: *Page, allocator: Allocator) ![]u8 {
//     //     const header = self.buffer.getHeader();
//     //     const header_bytes: []u8 = try header.serialize(allocator);
//     //
//     //     // only get initialized memory
//     //     const content_size = self.buffer.content.len;
//     //     const content = self.buffer.content[header.size..content_size];
//     //     defer buffer.deinit();
//     //
//     //     try buffer.appendSlice(header_bytes);
//     //     try buffer.appendSlice(content);
//     //     return try buffer.toOwnedSlice();
//     // }

//     pub fn insert(self: *Page, record: []u8) !void {
//         // Tries to insert a record into the page if there is enough space.
//         // 1. Reads the header to determine if there is space.
//         // 2. If there is space, inserts the record and updates header.
//         // 3. Updates the slot array
//         // 3. If there is no space, returns an error.

//         const header = self.buffer.getHeader();

//         if (header.free_space < record.len) {
//             return PageError.NotEnoughSpace;
//         }

//         var slot_array: SlotArray = undefined;
//         defer slot_array.deinit();

//         if (header.slot_array_size == 0) {
//             slot_array = try SlotArray.init(self.buffer.allocator);
//         } else {
//             slot_array = try SlotArray.deserialize(
//                 self.buffer.allocator,
//                 self.buffer.content[0..header.slot_array_size],
//             );
//         }

//         const record_starting_offset: u16 = @intCast(header.last_used_offset - record.len);
//         const record_ending_offset: u16 = header.last_used_offset;

//         // update slot array
//         try slot_array.insert(@intCast(record_starting_offset));
//         const slot_array_bytes = try slot_array.serialize();
//         defer self.buffer.allocator.free(slot_array_bytes.?);

//         // update header
//         const new_last_used_offset = record_starting_offset;
//         const new_slot_array_size = slot_array_bytes.?.len;
//         const new_free_space = header.free_space - record.len - 2;

//         const new_header = PageHeader{
//             .slot_array_size = @intCast(new_slot_array_size),
//             .last_used_offset = @intCast(new_last_used_offset),
//             .free_space = @intCast(new_free_space),
//         };

//         try self.buffer.setHeader(new_header);

//         // update content
//         var new_content = self.buffer.getContent();
//         @memcpy(
//             new_content[0..new_slot_array_size],
//             slot_array_bytes.?,
//         );
//         @memcpy(
//             new_content[record_starting_offset..record_ending_offset],
//             record,
//         );

//         try self.buffer.setContent(
//             new_content,
//         );
//     }
//     //
//     // pub fn update(self: *Page) void {
//     // TODO
//     // }

//     // pub fn delete(self: *Page) void {
//     // TODO
//     // }
//     //
//     pub fn format(
//         self: Page,
//         comptime fmt: []const u8,
//         options: std.fmt.FormatOptions,
//         writer: anytype,
//     ) !void {
//         _ = fmt;
//         _ = options;

//         const header = self.buffer.getHeader();
//         var slot_array = try SlotArray.deserialize(
//             self.buffer.allocator,
//             self.buffer.content[0..header.slot_array_size],
//         );
//         defer slot_array.deinit();

//         const row_amount = slot_array.slot_offsets.?.len;
//         var rows = ArrayList([]u8).init(self.buffer.allocator);
//         defer rows.deinit();

//         const content_size = self.buffer.content.len;

//         for (0..row_amount) |i| {
//             const start = slot_array.slot_offsets.?[i];
//             var end: u16 = 0;
//             if (i == 0) {
//                 end = @intCast(content_size);
//             } else {
//                 end = slot_array.slot_offsets.?[i - 1];
//             }
//             const row = self.buffer.content[start..end];
//             try rows.append(row);
//         }

//         const rows_slice = try rows.toOwnedSlice();
//         defer self.buffer.allocator.free(rows_slice);

//         try writer.print(
//             \\Page:
//             \\
//             \\  Header:
//             \\    SlotArraySize: {d},
//             \\    last_used_offset: {d},
//             \\    free_space: {d},
//             \\
//             \\  SlotArray: {any},
//             \\
//             \\  Rows: {any}
//             \\
//         ,
//             .{
//                 header.slot_array_size,
//                 header.last_used_offset,
//                 header.free_space,
//                 slot_array.slot_offsets,
//                 rows_slice,
//             },
//         );
//     }
// };

// /// Contains a header, content buffer and the total size of the page.
// pub const BufferWithHeader = struct {
//     header: []u8,
//     content: []u8,
//     size: u16,
//     allocator: Allocator,

//     pub fn init(allocator: Allocator, page_size: u16) !BufferWithHeader {

//         // initiating this will also initiate a PageHeader

//         const page_header = PageHeader.init(page_size);
//         const page_header_bytes = try page_header.serialize(allocator);

//         const header_size = @sizeOf(PageHeader);
//         const content_mem = try allocator.alloc(u8, page_size - header_size);
//         @memset(content_mem, 0);

//         return BufferWithHeader{
//             .header = page_header_bytes,
//             .content = content_mem,
//             .size = page_size,
//             .allocator = allocator,
//         };
//     }

//     pub fn deinit(self: *BufferWithHeader) void {
//         self.allocator.free(self.header);
//         self.allocator.free(self.content);
//     }

//     pub fn setHeader(self: *BufferWithHeader, header: PageHeader) !void {
//         const header_bytes: []u8 = try header.serialize(self.allocator);
//         @memcpy(self.header, header_bytes);
//         self.allocator.free(header_bytes);
//     }

//     pub fn setHeaderBytes(self: *BufferWithHeader, header_bytes: []u8) !void {
//         // const header_bytes: []u8 = try header.serialize(self.allocator);
//         @memcpy(self.header, header_bytes);
//         // self.allocator.free(header_bytes);
//     }

//     pub fn getHeader(self: BufferWithHeader) PageHeader {
//         const header = PageHeader.deserialize(self.header);
//         return header;
//     }

//     pub fn getContent(self: *BufferWithHeader) []u8 {
//         return self.content;
//     }

//     pub fn setContent(self: *BufferWithHeader, content: []u8) !void {
//         const new_content = try self.allocator.alloc(u8, self.size - @sizeOf(PageHeader));
//         @memcpy(new_content, content);
//         // self.allocator.free(self.content);
//         self.content = new_content;
//     }
// };

// test "bufferWithHeader_mem_leak" {
//     const allocator = tst.allocator;
//     const PAGE_SIZE: u16 = 4096;

//     var buffer = try BufferWithHeader.init(allocator, PAGE_SIZE);
//     defer buffer.deinit();
// }

// test "bufferWithHeader_setgetHeader" {
//     const allocator = tst.allocator;
//     const PAGE_SIZE: u16 = 4096;

//     var buffer = try BufferWithHeader.init(allocator, PAGE_SIZE);
//     defer buffer.deinit();

//     const header = PageHeader.init(PAGE_SIZE);
//     try buffer.setHeader(header);

//     const header_from_buffer = buffer.getHeader();
//     try tst.expect(header_from_buffer.slot_array_size == 0);
//     try tst.expect(header_from_buffer.last_used_offset == (PAGE_SIZE - @sizeOf(PageHeader)));
//     try tst.expect(header_from_buffer.free_space == (PAGE_SIZE - @sizeOf(PageHeader)));
// }

// test "SlotArray" {
//     const allocator = tst.allocator;
//     var slot_array = try SlotArray.init(allocator);
//     defer slot_array.deinit();

//     try slot_array.insert(0);
//     try slot_array.insert(2);
//     try slot_array.insert(4);

//     try tst.expect(slot_array.slot_offsets.?.len == 3);
//     try tst.expect(slot_array.slot_offsets.?[2] == 4);
// }

// test "serialize_SlotArray" {
//     const allocator = tst.allocator;
//     var slot_array = try SlotArray.init(allocator);
//     defer slot_array.deinit();

//     const null_serialized = try slot_array.serialize();
//     try tst.expect(null_serialized == null);

//     try slot_array.insert(0);
//     try slot_array.insert(2);
//     try slot_array.insert(99);

//     const serialized = try slot_array.serialize();
//     defer allocator.free(serialized.?);
//     try tst.expect(serialized != null);
//     try tst.expect(serialized.?.len == 6);

//     var new_slot_array = try SlotArray.deserialize(allocator, serialized.?);
//     defer new_slot_array.deinit();

//     try tst.expect(new_slot_array.slot_offsets.?.len == 3);
//     try tst.expect(new_slot_array.slot_offsets.?[2] == 99);
// }

// test "page" {
//     const allocator = tst.allocator;
//     const PAGE_SIZE: u16 = 4096;

//     var page = try Page.init(allocator, PAGE_SIZE);
//     defer page.buffer.deinit();

//     const record1 = "hello";
//     const record_bytes1 = try allocator.alloc(u8, record1.len);
//     defer allocator.free(record_bytes1);
//     @memcpy(record_bytes1, record1);

//     const record2 = "world";
//     const record_bytes2 = try allocator.alloc(u8, record2.len);
//     defer allocator.free(record_bytes2);
//     @memcpy(record_bytes2, record2);

//     const record3 = "!";
//     const record_bytes3 = try allocator.alloc(u8, record3.len);
//     defer allocator.free(record_bytes3);
//     @memcpy(record_bytes3, record3);

//     try page.insert(record_bytes1);
//     try page.insert(record_bytes2);
//     try page.insert(record_bytes3);

//     try tst.expect(page.buffer.getHeader().slot_array_size == 6);

//     // print("{any}\n", .{page});
// }

// test "insert_tuples" {
//     const allocator = std.testing.allocator;

//     const columns_lit = [_]DataType{
//         DataType.Int,
//         DataType.String,
//         DataType.Bool,
//     };
//     const columns = try allocator.dupe(DataType, &columns_lit);
//     defer allocator.free(columns);

//     // first row of data
//     const cell_values_lit_row1 = [_]CellValue{
//         CellValue{ .int_value = 42 },
//         CellValue{ .string_value = "hello" },
//         CellValue{ .bool_value = true },
//     };

//     const cell_values_row1 = try allocator.dupe(CellValue, &cell_values_lit_row1);
//     defer allocator.free(cell_values_row1);

//     // second row of data
//     const cell_values_lit_row2 = [_]CellValue{
//         CellValue{ .int_value = 32 },
//         CellValue{ .string_value = "world" },
//         CellValue{ .bool_value = false },
//     };

//     const cell_values_row2 = try allocator.dupe(CellValue, &cell_values_lit_row2);
//     defer allocator.free(cell_values_row2);

//     const tuple1 = try Tuple.create(allocator, 1, columns, cell_values_row1);
//     defer tuple1.deinit();

//     const tuple2 = try Tuple.create(allocator, 1, columns, cell_values_row2);
//     defer tuple2.deinit();

//     const record_bytes_row1 = try tuple1.serialize();
//     const record_bytes_row2 = try tuple2.serialize();
//     defer allocator.free(record_bytes_row1);
//     defer allocator.free(record_bytes_row2);

//     const PAGE_SIZE: u16 = 4096;
//     var page = try Page.init(allocator, PAGE_SIZE);
//     defer page.deinit();

//     try page.insert(record_bytes_row1);
//     try page.insert(record_bytes_row2);
//     print("{any}\n", .{page});
// }

// test "large_page" {
//     const allocator = tst.allocator;
//     const PAGE_SIZE: u16 = 8192;

//     var page = try Page.init(allocator, PAGE_SIZE);
//     defer page.buffer.deinit();

//     const record1 = "hello";
//     const record_bytes1 = try allocator.alloc(u8, record1.len);
//     defer allocator.free(record_bytes1);
//     @memcpy(record_bytes1, record1);

//     const record2 = "world";
//     const record_bytes2 = try allocator.alloc(u8, record2.len);
//     defer allocator.free(record_bytes2);
//     @memcpy(record_bytes2, record2);

//     const record3 = "!";
//     const record_bytes3 = try allocator.alloc(u8, record3.len);
//     defer allocator.free(record_bytes3);
//     @memcpy(record_bytes3, record3);

//     try page.insert(record_bytes1);
//     try page.insert(record_bytes2);
//     try page.insert(record_bytes3);

//     try tst.expect(page.buffer.getHeader().slot_array_size == 6);

//     // print("{any}\n", .{page});
// }

// test "page_serialize_deserialize" {
//     var log_allocator = std.heap.loggingAllocator(tst.allocator);
//     // defer log_allocator.deinit();

//     const allocator = log_allocator.allocator();

//     const PAGE_SIZE: u16 = 4096;

//     var page = try Page.init(allocator, PAGE_SIZE);
//     defer page.deinit();

//     const record1 = "hello";
//     const record_bytes1 = try allocator.alloc(u8, record1.len);
//     defer allocator.free(record_bytes1);
//     @memcpy(record_bytes1, record1);

//     try page.insert(record_bytes1);

//     const serialized_page = try page.serialize(allocator);
//     defer allocator.free(serialized_page);

//     var deserialized_page = try Page.deserialize(allocator, serialized_page);
//     defer deserialized_page.deinit();

//     try tst.expect(page.buffer.getHeader().slot_array_size == deserialized_page.buffer.getHeader().slot_array_size);
// }
