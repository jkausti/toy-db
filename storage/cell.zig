const std = @import("std");
const print = std.debug.print;
const expect = std.testing.expect;
const tst = std.testing;
const Alloc = std.mem.Allocator;
const DataType = @import("column.zig").DataType;
const Column = @import("column.zig").Column;

pub const CellValue = union(enum) {
    int_value: i32,
    bigint_value: i64,
    string_value: []const u8,
    float_value: f32,
    bool_value: bool,

    pub fn format(
        self: CellValue,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        return switch (self) {
            CellValue.int_value => |v| {
                try writer.print("{d}", .{v});
            },
            CellValue.bigint_value => |v| {
                try writer.print("{d}", .{v});
            },
            CellValue.string_value => |v| {
                try writer.print("{s}", .{v});
            },
            CellValue.float_value => |v| {
                try writer.print("{d}", .{v});
            },
            CellValue.bool_value => |v| {
                try writer.print("{}", .{v});
            },
        };
    }
};

pub const CellError = error{
    DataTypeMismatch,
    UnsupportedDataType,
};

// pub fn Cell(comptime T: type) type {
//     return struct {
//         const Self = @This();

//         column_metadata: Column,
//         data: CellValue,

//         pub fn create(value: T, column_metadata: Column) !Self {
//             const cell_type = @TypeOf(value);

//             if (cell_type == i32) {
//                 if (column_metadata.data_type != DataType.Int) {
//                     return CellError.DataTypeMismatch;
//                 } else {
//                     return Self{
//                         .column_metadata = column_metadata,
//                         .data = CellValue{ .int_value = value },
//                     };
//                 }
//             } else if (cell_type == i64) {
//                 if (column_metadata.data_type != DataType.BigInt) {
//                     return CellError.DataTypeMismatch;
//                 } else {
//                     return Self{
//                         .column_metadata = column_metadata,
//                         .data = CellValue{ .big_int = value },
//                     };
//                 }
//             } else if (cell_type == []const u8) {
//                 if (column_metadata.data_type != DataType.String) {
//                     return CellError.DataTypeMismatch;
//                 } else {
//                     return Self{
//                         .column_metadata = column_metadata,
//                         .data = CellValue{ .string_value = value },
//                     };
//                 }
//             } else if (cell_type == f32) {
//                 if (column_metadata.data_type != DataType.Float) {
//                     return CellError.DataTypeMismatch;
//                 } else {
//                     return Self{
//                         .column_metadata = column_metadata,
//                         .data = CellValue{ .float_value = value },
//                     };
//                 }
//             } else if (cell_type == bool) {
//                 if (column_metadata.data_type != DataType.Bool) {
//                     return CellError.DataTypeMismatch;
//                 } else {
//                     return Self{
//                         .column_metadata = column_metadata,
//                         .data = CellValue{ .bool_value = value },
//                     };
//                 }
//             } else {
//                 return CellError.UnsupportedDataType;
//             }
//         }

//         pub fn update(self: *Self, value: T) !void {
//             const cell_type = @TypeOf(value);
//             const column_metadata = self.column_metadata;

//             if (cell_type == i32 or cell_type == u32 or cell_type == i64 or cell_type == u64) {
//                 if (column_metadata.data_type != DataType.Int) {
//                     return CellError.DataTypeMismatch;
//                 } else {
//                     self.data.int_value = value;
//                 }
//             } else if (cell_type == []const u8) {
//                 if (column_metadata.data_type != DataType.String) {
//                     return CellError.DataTypeMismatch;
//                 } else {
//                     self.data.string_value = value;
//                 }
//             } else if (cell_type == f32) {
//                 if (column_metadata.data_type != DataType.Float) {
//                     return CellError.DataTypeMismatch;
//                 } else {
//                     self.data.float_value = value;
//                 }
//             } else if (cell_type == bool) {
//                 if (column_metadata.data_type != DataType.Bool) {
//                     return CellError.DataTypeMismatch;
//                 } else {
//                     self.data.bool_value = value;
//                 }
//             } else {
//                 return CellError.UnsupportedDataType;
//             }
//         }
//     };
// }

// test "cell_datatype_correct" {
//     const column = Column{ .name = "age", .data_type = DataType.Int };
//     const value_to_store: i32 = 5;
//     const cell = try Cell(i32).create(value_to_store, column);

//     try tst.expectEqual(cell.column_metadata.data_type, DataType.Int);
//     try tst.expectEqual(cell.data.int_value, 5);
// }

// test "cell_unsupported_datatype" {
//     const column = Column{ .name = "age", .data_type = DataType.Int };
//     const value_to_store: i128 = 5;
//     const cell = Cell(i128).create(value_to_store, column);

//     try tst.expectError(CellError.UnsupportedDataType, cell);
// }

// test "cell_wrong_datatype" {
//     const column = Column{ .name = "name", .data_type = DataType.String };
//     const value_to_store: i32 = 5;
//     const cell = Cell(i32).create(value_to_store, column);

//     try tst.expectError(CellError.DataTypeMismatch, cell);
// }

// test "cell_update" {
//     const column = Column{ .name = "name", .data_type = DataType.Int };
//     const orig_value: i32 = 5;
//     var cell = try Cell(i32).create(orig_value, column);

//     const value: i32 = 10;
//     try cell.update(value);

//     try tst.expectEqual(cell.data.int_value, 10);
// }
