const std = @import("std");
const File = std.fs.File;
const storage = @import("storage");
const BufferManager = storage.buffermanager.BufferManager;
const Allocator = std.mem.Allocator;

// pub fn getDb(file_handle: File, name: []const u8) !Database {}

const Database = struct {
    database_name: []const u8,
    file_handle: File,
    database_header: DatabaseHeader,
    buffer_manager: BufferManager,

    pub fn init(allocator: Allocator, file_handle: File) !Database {
        const name = allocator.alloc(u8, file_handle.name().len);
        defer allocator.free(name);

        const database_header = DatabaseHeader.init(allocator, name);
        const db = Database{
            .database_name = file_handle.name(),
            .file_handle = file_handle,
            .database_header = database_header,
            .buffer_manager = BufferManager.init(allocator, file_handle),
        };
        return db;
    }
};
