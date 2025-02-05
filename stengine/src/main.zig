const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const test_alloc = std.testing.allocator;
const ArrayList = std.ArrayList;
const expect = std.testing.expect;

pub const CellValue = union(enum) {
    int_value: i32,
    string_value: []const u8,
    float_value: f32,
    bool_value: bool,
};

pub const DataType = enum {
    Int,
    String,
    Float,
    Bool,
};

pub const Column = struct {
    name: []const u8,
    data_type: DataType,
};

pub fn Cell(comptime T: type) type {
    return struct {
        const Self = @This();

        column_metadata: Column,
        data: CellValue,

        pub const CellError = error{
            DataTypeMismatch,
            UnsupportedDataType,
        };

        pub fn create(data_value: T, column_metadata: Column) !Self {
            const cell_type = @TypeOf(data_value);
            var input_type: DataType = undefined;

            // make sure input data matches defined column data type
            if (cell_type == i32 or cell_type == u32 or cell_type == i64 or cell_type == u64) {
                input_type = DataType.Int;
                if (column_metadata.data_type != DataType.Int) {
                    return CellError.DataTypeMismatch;
                }
            } else if (cell_type == []const u8) {
                input_type = DataType.String;
                if (column_metadata.data_type != DataType.String) {
                    return CellError.DataTypeMismatch;
                }
            } else if (cell_type == f32) {
                input_type = DataType.Float;
                if (column_metadata.data_type != DataType.Float) {
                    return CellError.DataTypeMismatch;
                }
            } else if (cell_type == bool) {
                input_type = DataType.Bool;
                if (column_metadata.data_type != DataType.Bool) {
                    return CellError.DataTypeMismatch;
                }
            } else {
                return CellError.UnsupportedDataType;
            }

            const data: CellValue = undefined;

            if (input_type == DataType.String) {
                data = CellValue{ .string_value = data_value };
            } else if (input_type == DataType.Int) {
                data = CellValue{ .int_value = data_value };
            } else if (input_type == DataType.Float) {
                data = CellValue{ .float_value = data_value };
            } else if (input_type == DataType.Bool) {
                data = CellValue{ .bool_value = data_value };
            }

            return Self{
                .column_metadata = column_metadata,
                .data = data,
            };
        }
    };
}

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

    // const deserialized_record = try record.deserialize(aa);
}

test "cell" {
    const column = Column{ .name = "age", .data_type = DataType.Int };
    const value_to_store: i32 = 5;
    _ = try Cell(i32).create(value_to_store, column);

    // expect(cell.column_metadata.data_type == DataType.Int);
    // expect(cell.data.int_value == 5);
}
