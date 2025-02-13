pub const DataType = enum {
    Int,
    BigInt,
    String,
    Float,
    Bool,
};

pub const Column = struct {
    name: []const u8,
    data_type: DataType,
};

pub const TableHeader = struct {
    columns: []Column,
};
