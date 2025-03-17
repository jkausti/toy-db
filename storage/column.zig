const std = @import("std");
const tst = std.testing;

// pub const DataType = enum(u8) {
//     Int = 1,
//     BigInt = 2,
//     String = 3,
//     Float = 4,
//     Bool = 5,
//
//     pub fn get(self: DataType) type {
//         switch (self) {
//             DataType.Int => return i32,
//             DataType.BigInt => return i64,
//             DataType.String => return []const u8,
//             DataType.Float => return f32,
//             DataType.Bool => return bool,
//         }
//     }
// };

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

pub const TableSchema = struct {
    name: [][]const u8,
    data_types: []DataType,
};

pub const TableHeader = struct {
    columns: []Column,
};
