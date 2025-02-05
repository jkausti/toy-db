const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const Datatype = enum(type) {
    Int = i64,
    String = []const u8,
    Bool = bool,
};

pub const Column = struct {
    name: []const u8,
    type: Datatype,
};


// pub fn Cell() type {
//     return struct {
//         column_metadata: *Column,
//         data: column_metadata.type,
//
//         pub fn init(column_metadata: *Column, data: T) Cell {
//             return Cell{
//                 .column_metadata = column_metadata,
//                 .data = data,
//             };
//         }
//     };
// }

const Cell = struct {
    column_metadata: *Column,
    data: column_metadata.type,

    pub fn init(column_metadata: *Column, data: Datatype) Cell {
        if (@typeOf(data) != column_metadata.type) {
            @compileError("Data type does not match column type");
        }
        return Cell{
            .column_metadata = column_metadata,
            .data = data,
        };
    }
};

pub const Record = struct {
    id: u64,
    cells: []Cell,

    pub fn serialize(self: Record, allocator: Allocator) []const u8 {
        var buffer = ArrayList(u8).init(allocator);
        defer buffer.deinit();

        try buffer.append(std.mem.asBytes(&id));
        // allocate memory for cells
        for (self.cells) |cell| {
            const cell_data = cell.data;
            try buffer.append(std.mem.asBytes(&cell_data));
        }
        return buffer.toOwnedSlice();
    }
};

pub const PageHeader = struct {
    page_id: u64,
    page_size: u64,
    record_size: u64,
    record_count: u64,

    pub fn serialize(self: PageHeader, allocator: Allocator) []const u8 {
        var buffer = [32]u8{};

        std.mem.writeInt(u64, buffer[0..8], self.page_id, .little);
        std.mem.writeInt(u64, buffer[8..16], self.page_size, .little);
        std.mem.writeInt(u64, buffer[16..24], self.record_size, .little);
        std.mem.writeInt(u64, buffer[24..32], self.record_count, .little);

        return buffer;
    }
};


pub const Page = struct {
    header: PageHeader,
    records: []Record,
    page_size: 4096,
    curr_size: u32,
    allocator: Allocator,
    
    
    pub fn setRecords(self: Page, records: []Record, allocator: Allocator) void {
        var size = 0;
        self.records = records;
        self.allocator = allocator;
    }

    pub fn serialize(self: Page, allocator: Allocator) []const u8 {
        var page_size = 4096;
        var buffer: [page_size]u8 = undefined;

        for (self.records) |record| {
            const record_data = record.serialize(allocator);
            const record_size = record_data.len;
            if (self.curr_size + record_size > page_size) {
    }
};
