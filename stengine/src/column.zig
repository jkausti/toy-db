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
