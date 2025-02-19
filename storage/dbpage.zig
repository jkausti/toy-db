const std = @import("std");
const AutoArrayHashMap = std.array_hash_map.AutoArrayHashMap;
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const tst = std.testing;

const SIZE: u32 = 131072; // 128kib

const DbPage = struct {
    db_name: []const u8,
    allocator: Allocator,
    schema_table_map: AutoArrayHashMap([]const u8, [][]const u8),

    pub fn init(allocator: Allocator, db_name: []const u8) !DbPage {

        // create sys schema
        var schema_table_map = AutoArrayHashMap([]const u8, [][]const u8).init(allocator);
        // defer table_schemas.deinit();

        const sys_tables = try allocator.alloc([]u8, 2);
        const tables = try allocator.dupe(u8, "tables");
        const schemas = try allocator.dupe(u8, "schemas");

        sys_tables[0] = tables;
        sys_tables[1] = schemas;

        try schema_table_map.put("sys", sys_tables[0..]);

        return DbPage{
            .db_name = db_name,
            .schema_table_map = schema_table_map,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DbPage) void {
        self.schema_table_map.deinit();
    }
};

test "DbPage" {
    const allocator = tst.allocator;

    var page_zero = try DbPage.init(allocator, "test_db");
    defer page_zero.deinit();

    const tables = page_zero.schema_table_map.get("sys").?;
    print("{s}\n", .{tables});
    try tst.expect(tables.len == 2);
    try tst.expect(std.mem.eql(u8, tables[0], "tables"));
    try tst.expect(std.mem.eql(u8, tables[1], "schemas"));

    page_zero.deinit();
}
