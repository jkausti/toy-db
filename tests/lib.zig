const std = @import("std");
const storage = @import("storage");

// Re-export the test file so its tests are included
pub usingnamespace @import("buffermanager_test.zig");

pub fn main() !void {
    std.testing.refAllDecls(@This());
    // add tests here
    std.testing.refAllDecls(@import("buffermanager_test.zig"));
    std.testing.refAllDecls(@import("page_test.zig"));
    std.testing.refAllDecls(@import("pagedirectory_test.zig"));
    std.testing.refAllDecls(@import("tuple_test.zig"));
}

// This test block ensures that tests are discovered
test {
    std.testing.refAllDecls(@This());
}
