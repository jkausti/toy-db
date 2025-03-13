const std = @import("std");
const File = std.fs.File;
const PageBuffer = @import("page.zig").PageBuffer;
const PageDirectory = @import("page.zig").PageDirectory;

pub fn createDbFile(path: []const u8) !File {}
