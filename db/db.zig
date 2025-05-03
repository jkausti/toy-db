const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const File = std.fs.File;

const storage = @import("storage");
const BufferManager = storage.buffermanager.BufferManager;

const DBError = error{
    InvalidDatabase,
    NotImplemented,
};

pub const Database = struct {
    db_file_handle: std.fs.File,
    buffer_manager: BufferManager,

    pub fn init(allocator: Allocator, absolute_db_path: []const u8, db_exists: bool) !Database {
        const file = switch (db_exists) {
            true => blk: {
                const file = try std.fs.openFileAbsolute(absolute_db_path, .{ .mode = .read_write });
                var signature = [_]u8{0} ** 7;
                _ = try file.read(&signature);
                print("Signature: {s}\n", .{signature});
                if (std.mem.eql(u8, &signature, "dbstar2")) {
                    print("File is a valid database.\n", .{});
                } else {
                    print("File is not a valid database.\n", .{});
                    return DBError.InvalidDatabase;
                }
                break :blk file;
            },
            false => try std.fs.createFileAbsolute(absolute_db_path, .{}),
        };

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
        self.buffer_manager.deinit();
        self.db_file_handle.close();
    }

    // pub fn createTable(
    //     self: Database,
    //     schema_name: []const u8,
    //     table_name []const u8,
    //     columns: []Column,
    // ) !void {
    //     const columns = [3]Column{
    //         Column{ .name = "id", .data_type = DataType.BigInt },
    //         Column{ .name = "name", .data_type = DataType.String },
    //         Column{ .name = "age", .data_type = DataType.Int },
    //     };
    // }
};
