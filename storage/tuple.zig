const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const Cell = @import("cell.zig").Cell;
const CellValue = @import("cell.zig").CellValue;
const DataType = @import("column.zig").DataType;
const CellError = @import("cell.zig").CellError;

/// A tuple consists of a collection of Cells.
///
///
pub const Tuple = struct {
    columns: []DataType,
    data: []CellValue,
    allocator: Allocator,

    pub fn create(
        alloc: Allocator,
        columns: []DataType,
        data: []CellValue,
    ) !Tuple {
        const col_cpy = try alloc.dupe(DataType, columns);
        const data_cpy = try alloc.dupe(CellValue, data);

        return Tuple{
            .columns = col_cpy,
            .data = data_cpy,
            .allocator = alloc,
        };
    }

    pub fn deinit(self: Tuple) void {
        self.allocator.free(self.columns);
        self.allocator.free(self.data);
    }

    pub fn serialize(self: Tuple) ![]u8 {
        // get size of tuple
        var size: usize = 0;

        for (self.columns, self.data) |coltype, cell| {
            switch (coltype) {
                DataType.Int => {
                    size += 4;
                },
                DataType.BigInt => {
                    size += 8;
                },
                DataType.String => {
                    const str_len: usize = switch (cell) {
                        CellValue.string_value => |val| val.len,
                        else => {
                            return CellError.DataTypeMismatch;
                        },
                    };
                    size += 2 + str_len;
                },
                DataType.Float => {
                    size += 4;
                },
                DataType.Bool => {
                    size += 1;
                },
            }
        }

        var bytes = try self.allocator.alloc(u8, size);

        var offset: u32 = 0;

        for (self.columns, self.data) |coltype, cell| {
            switch (coltype) {
                DataType.Int => {
                    _ = std.mem.writeInt(
                        i32,
                        @as(*[4]u8, @ptrCast(bytes[offset .. offset + 4])),
                        cell.int_value,
                        .little,
                    );
                    offset += 4;
                },
                DataType.BigInt => {
                    _ = std.mem.writeInt(
                        i64,
                        @as(*[8]u8, @ptrCast(bytes[offset .. offset + 8])),
                        cell.bigint_value,
                        .little,
                    );
                    offset += 8;
                },
                DataType.String => {
                    const string_length: u16 = @intCast(cell.string_value.len);
                    std.mem.writeInt(
                        u16,
                        @as(*[2]u8, @ptrCast(bytes[offset .. offset + 2])),
                        string_length,
                        .little,
                    );
                    offset += 2;
                    @memcpy(bytes[offset .. offset + string_length], cell.string_value[0..string_length]);
                    offset += string_length;
                },
                DataType.Float => {
                    const bit_pattern: u32 = @bitCast(cell.float_value);
                    _ = std.mem.writeInt(
                        u32,
                        @as(*[4]u8, @ptrCast(bytes[offset .. offset + 4])),
                        bit_pattern,
                        .little,
                    );
                    offset += 4;
                },
                DataType.Bool => {
                    _ = std.mem.writeInt(
                        u8,
                        @as(*[1]u8, @ptrCast(bytes[offset .. offset + 1])),
                        @intFromBool(cell.bool_value),
                        .little,
                    );
                    offset += 1;
                },
            }
        }

        return bytes;
    }

    pub fn deserialize(alloc: Allocator, columns: []DataType, bytes: []u8) !Tuple {
        const cell_values = try alloc.alloc(CellValue, columns.len);
        const columns_duped = try alloc.dupe(DataType, columns);

        var offset: usize = 0;
        for (columns_duped, 0..) |coltype, i| {
            // const cell_value: *CellValue = try alloc.create(CellValue);
            var cell_value: CellValue = undefined;
            switch (coltype) {
                DataType.Int => {
                    const int_size = 4;
                    const int_value = std.mem.readInt(
                        i32,
                        @as(*[4]u8, @ptrCast(bytes[offset .. offset + int_size])),
                        .little,
                    );
                    cell_value = CellValue{ .int_value = int_value };
                    offset = offset + int_size;
                },
                DataType.BigInt => {
                    const bigint_size = 8;
                    const bigint_value = std.mem.readInt(
                        i64,
                        @as(*[8]u8, @ptrCast(bytes[offset .. offset + bigint_size])),
                        .little,
                    );
                    cell_value = CellValue{ .bigint_value = bigint_value };
                    offset = offset + bigint_size;
                },
                DataType.String => {
                    const string_length = std.mem.readInt(
                        u16,
                        @as(*[2]u8, @ptrCast(bytes[offset .. offset + 2])),
                        .little,
                    );
                    offset = offset + 2;
                    const string_value = bytes[offset .. offset + string_length];
                    cell_value = CellValue{ .string_value = string_value };
                    offset = offset + string_length;
                },
                DataType.Float => {
                    const float_size = 4;
                    const bit_pattern = std.mem.readInt(
                        u32,
                        @as(*[float_size]u8, @ptrCast(bytes[offset .. offset + float_size])),
                        .little,
                    );
                    const float_value: f32 = @bitCast(bit_pattern);
                    cell_value = CellValue{ .float_value = float_value };
                    offset = offset + float_size;
                },
                DataType.Bool => {
                    const bool_size = 1;
                    const int_value = std.mem.readInt(
                        u8,
                        @as(*[bool_size]u8, @ptrCast(bytes[offset .. offset + bool_size])),
                        .little,
                    );
                    const bool_value: bool = int_value != 0;
                    cell_value = CellValue{ .bool_value = bool_value };
                    offset = offset + bool_size;
                },
            }
            cell_values[i] = cell_value;
        }

        return Tuple{
            .columns = columns_duped,
            .data = cell_values,
            .allocator = alloc,
        };
    }

    pub fn format(
        self: Tuple,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print("{any}", .{self.data});
    }
};

test "Tuple" {
    const allocator = std.testing.allocator;

    const columns_lit = [_]DataType{
        DataType.Int,
        DataType.String,
        DataType.Bool,
    };
    const columns = try allocator.dupe(DataType, &columns_lit);
    defer allocator.free(columns);

    const cell_values_lit = [_]CellValue{
        CellValue{ .int_value = 42 },
        CellValue{ .string_value = "hello" },
        CellValue{ .bool_value = true },
    };

    const cell_values = try allocator.dupe(CellValue, &cell_values_lit);
    defer allocator.free(cell_values);

    const tuple = try Tuple.create(allocator, columns, cell_values);
    defer tuple.deinit();

    const bytes = try tuple.serialize();
    defer allocator.free(bytes);

    const deserialized = try Tuple.deserialize(allocator, columns, bytes);
    defer deserialized.deinit();

    try std.testing.expect(tuple.columns[0] == deserialized.columns[0]);
    try std.testing.expect(tuple.data.len == deserialized.data.len);
    try std.testing.expect(std.mem.eql(u8, tuple.data[1].string_value, deserialized.data[1].string_value));
}
