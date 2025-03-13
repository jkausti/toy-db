const std = @import("std");
const tst = std.testing;
const storage = @import("storage");
const CellValue = storage.column.CellValue;

// 5 rows of 5 columns

test "getInitialMasterData" {
    const data = getInitialMasterData();

    try tst.expectEqual(data[0][0].string, "sys");
    try tst.expectEqual(data[0][1].string, "dbstar_master");
    try tst.expectEqual(data[5][5].string, "string");
}
