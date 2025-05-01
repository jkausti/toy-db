const std = @import("std");
pub const db = @import("db.zig");

pub fn main() !void {
    std.testing.refAllDecls(@This());
}
