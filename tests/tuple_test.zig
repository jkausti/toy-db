const std = @import("std");
const tst = std.testing;
const storage = @import("storage");

const Tuple = storage.tuple.Tuple;
const DataType = storage.data_type.DataType;
const CellValue = storage.cell.CellValue;

test "Tuple" {
    const allocator = tst.allocator;

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

    try tst.expect(tuple.columns[0] == deserialized.columns[0]);
    try tst.expect(tuple.data.len == deserialized.data.len);
    try tst.expect(std.mem.eql(u8, tuple.data[1].string_value, deserialized.data[1].string_value));
}
