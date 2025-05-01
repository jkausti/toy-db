const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const File = std.fs.File;

const storage = @import("storage");
const BufferManager = storage.buffermanager.BufferManager;

pub const Database = struct {
    db_file_handle: std.fs.File,
    buffer_manager: BufferManager,

    pub fn init(allocator: Allocator, absolute_db_path: []const u8, db_exists: bool) !Database {
        const file = try std.fs.openFileAbsolute(absolute_db_path, .{});

        // check if file is actually a database

        const last_slash_index = std.mem.lastIndexOf(u8, absolute_db_path, "/");
        var db_name_start: usize = undefined;

        if (last_slash_index == null) {
            db_name_start = 0;
        } else {
            db_name_start = last_slash_index.? + 1;
        }
        const db_name = absolute_db_path[db_name_start..];

        var buffer_manager: BufferManager = undefined;
        if (!db_exists) {
            buffer_manager = try BufferManager.init(allocator, db_name, null);
        } else if (db_exists) {
            buffer_manager = try BufferManager.init(allocator, db_name, file);
        }

        const db = Database{
            .db_file_handle = file,
            .buffer_manager = buffer_manager,
        };

        return db;
    }

    pub fn deinit(self: *Database) void {
        self.db_file_handle.close();
        self.buffer_manager.deinit();
    }
};
