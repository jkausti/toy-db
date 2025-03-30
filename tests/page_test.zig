const std = @import("std");
const tst = std.testing;
const Allocator = std.mem.Allocator;
const storage = @import("storage");
const SlotArray = storage.page_buffer.SlotArray;
const PageBuffer = storage.page_buffer.PageBuffer;
const Tuple = storage.tuple.Tuple;
const DataType = storage.column.DataType;
const CellValue = storage.cell.CellValue;
const PageHeader = storage.page_buffer.PageHeader;

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
    const allocator = tst.allocator;

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
    const allocator = tst.allocator;

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
