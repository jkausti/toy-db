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
