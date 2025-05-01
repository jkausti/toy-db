# Storage Module Documentation

This document provides an overview of the functionality and purpose of each
file within the `storage` module of the project. The `storage` module is
responsible for managing data storage, serialization, and deserialization
processes. It includes components for handling tuples, pages, page directories,
buffer management, and more.

## File Descriptions

### 1. `buffermanager.zig`

The `buffermanager.zig` file defines the `BufferManager` structure, which is
responsible for managing pages in memory. It handles the loading and flushing
of pages to and from disk, ensuring that only necessary pages are kept in
memory to optimize performance. The `BufferManager` maintains a page directory
and a master root page, both of which are always present in memory. It also
manages a page table, which contains pages that are swapped in and out of
memory as needed.

Key functionalities include:
- Initialization and deinitialization of the buffer manager.
- Loading and flushing pages to disk.
- Managing the master page, which contains metadata about the database schema.
- Adding new pages to the buffer manager and updating the master page with
schema information.

### 2. `cell.zig`

The `cell.zig` file defines the `CellValue` union, which represents the
possible values that a cell in a tuple can hold. It includes various data types
such as integers, big integers, strings, floats, and booleans. The file also
defines the `CellError` error set, which includes errors related to data type
mismatches and unsupported data types.

Key functionalities include:
- Formatting cell values for output.
- Handling different data types within a cell.

### 3. `column.zig`

The `column.zig` file defines the `DataType` enumeration and the `Column`
structure. The `DataType` enumeration lists the possible data types that a
column can have, including integers, big integers, strings, floats, and
booleans. The `Column` structure represents a column in a database table, with
a name and a data type.

Key functionalities include:
- Converting data types to their string representations.
- Defining the structure of a column in a database table.

### 4. `lib.zig`

The `lib.zig` file serves as the main entry point for the storage module. It
imports all the necessary components from other files within the module, such
as the buffer manager, page buffer, page directory, data type, column, cell,
and tuple. The `main` function is defined here, which references all
declarations in the module for testing purposes.

Key functionalities include:
- Importing and organizing the components of the storage module.
- Providing a main entry point for testing the module.

### 5. `page.zig`

The `page.zig` file defines structures and functions related to managing pages
in the database. It includes the `PageHeader` structure, which contains
metadata about a page, and the `SlotArray` structure, which manages the offsets
of records within a page. The `PageBuffer` structure is responsible for
managing the byte array that represents a page in memory.

Key functionalities include:
- Initializing and deinitializing pages.
- Inserting tuples into pages and managing free space.
- Serializing and deserializing page headers and slot arrays.

### 6. `pagedirectory.zig`

The `pagedirectory.zig` file defines the `PageDirectory` structure, which
represents the first page of the database file. It contains metadata about the
database and manages the directory of pages. The `DbMetadata` structure is also
defined here, which holds metadata about the database, such as the signature,
database name, and page count.

Key functionalities include:
- Initializing and deinitializing the page directory.
- Serializing and deserializing database metadata.
- Managing the directory of pages and retrieving page offsets.

### 7. `tuple.zig`

The `tuple.zig` file defines the `Tuple` structure, which represents a
collection of cells. It includes functions for creating, deinitializing,
serializing, and deserializing tuples. The `Tuple` structure is used to manage
the data within a page, allowing for efficient storage and retrieval of
records.

Key functionalities include:
- Creating and deinitializing tuples.
- Serializing and deserializing tuples for storage.
- Formatting tuples for output.

## Conclusion

The `storage` module provides a comprehensive set of functionalities for
managing data storage in the database. It includes components for handling
tuples, pages, page directories, and buffer management, ensuring efficient
storage and retrieval of data. Each file within the module plays a crucial role
in achieving these goals, contributing to the overall functionality of the
database system.

