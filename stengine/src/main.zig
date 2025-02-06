const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const test_alloc = std.testing.allocator;
const ArrayList = std.ArrayList;
const expect = std.testing.expect;
const tst = std.testing;
const Cell = @import("cell.zig").Cell;
const Column = @import("cell.zig").Column;
const DataType = @import("cell.zig").DataType;

pub const Record = struct {
    id: u64,
    cells: []Cell,

    pub fn create(id: u64, cells: []Cell) Record {
        return Record{
            .id = id,
            .cells = cells,
        };
    }

    pub fn serialize(self: Record, allocator: Allocator) ![]const u8 {
        var buffer = ArrayList(u8).init(allocator);
        defer buffer.deinit();

        try buffer.appendSlice(std.mem.asBytes(&self.id));
        // allocate memory for cells
        for (self.cells) |cell| {
            try buffer.appendSlice(std.mem.asBytes(&cell.data));
        }
        return buffer.toOwnedSlice();
    }

    // pub fn deserialize(allocator: Allocator, data: []const u8) ![]Record {
    //     var index = 0;
    //     const record_id = std.mem.readInt(u64, data[0..4]);
    //
    // }
};

pub const TableHeader = struct {
    columns: []Column,
};

pub const Table = struct {
    header: TableHeader,
    records: []Record,

    pub fn create(columns: []Column, records: []Record) Table {
        return Table{
            .columns = columns,
            .records = records,
        };
    }
};

pub fn main() !void {
    // get arena allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    // create and allocate strings
    const string_lit_1 = "number_5";
    const string_lit_2 = "number_10";
    const string_lit_3 = "number_20";

    const column_name_1 = try aa.alloc(u8, string_lit_1.len + 1);
    @memcpy(column_name_1[0..string_lit_1.len], "number_5");
    const column_name_2 = try aa.alloc(u8, string_lit_2.len + 1);
    @memcpy(column_name_2[0..string_lit_2.len], "number_10");
    const column_name_3 = try aa.alloc(u8, string_lit_3.len + 1);
    @memcpy(column_name_1[0..string_lit_3.len], "number_20");

    // create columns
    const column_1 = try Column.create(aa, column_name_1, DataType.Int);
    const column_2 = try Column.create(aa, column_name_2, DataType.Int);
    const column_3 = try Column.create(aa, column_name_3, DataType.Int);

    // create values
    const cell_1 = Cell.init(column_1, 5);
    const cell_2 = Cell.init(column_2, 10);
    const cell_3 = Cell.init(column_3, 20);

    var cell_slice = try aa.alloc(Cell, 3);
    cell_slice[0] = cell_1;
    cell_slice[1] = cell_2;
    cell_slice[2] = cell_3;

    const record = Record.create(1, cell_slice);

    const serialized_record = try record.serialize(aa);

    print("Serialized record: {x}\n", .{serialized_record});
}
