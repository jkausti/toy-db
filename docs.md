### Startup

1. Conditional: If db-file given as parameter on startup exists

- True: open it and load first page.
- False: create a new db-file and write a default first page.
  - Requires:
    - I can create rows and a table.

2. Give prompt to user.

### BufferManager Initialization

The `BufferManager` is responsible for managing the pages in memory and on disk.
It is initialized with the following steps:

1. **Parameters**: The `init` function of `BufferManager` requires an
   `Allocator`, a `database_name` as a slice of `u8`, and an optional `File`
   handle.

2. **Existing Database**:

   - If a `File` handle is provided, the `BufferManager` reads the page directory page
     and the master page from the file into memory.
   - It deserializes the `PageDirectory` from the first page and initializes the
     `master_root_page` with the subsequent bytes.

3. **New Database**:

   - If no `File` handle is provided, a new `PageDirectory` is initialized with
     the given `database_name`.
   - A new `master_root_page` is created using the `initMaster` function.

4. **Page Table**: An `ArrayList` of `PageTableEntry` is initialized to manage
   the pages that are swapped in and out of memory.

5. **Return**: The function returns an instance of `BufferManager` with the
   initialized components.

This process ensures that the `BufferManager` is correctly set up to handle page
management for both existing and new databases.
