const std = @import("std");
const File = std.fs.File;
const storage = @import("storage");

pub fn getDb(file_handle: File, name: []const u8) !Database {}

const Database = struct {
    database_name: []const u8,
    file_handle: File,
    page_zero: PageZero,

    pub fn init(file_handle: File) !Database {
        const db = Database{
            .database_name = file_handle.name(),
            .file_handle = file_handle,
        };
        return db;
    }

    pub fn getTables(self: *Database) ![]Table {
        return storage.getTables(self.file_handle);
    }
};
