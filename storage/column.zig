const std = @import("std");
const tst = std.testing;

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

    pub fn datatypeAsString(self: Column) []const u8 {
        return switch (self.data_type) {
            DataType.Int => {
                return "int";
            },
            DataType.BigInt => {
                return "bigint";
            },
            DataType.String => {
                return "string";
            },
            DataType.Float => {
                return "float";
            },
            DataType.Bool => {
                return "bool";
            },
        };
    }
};
