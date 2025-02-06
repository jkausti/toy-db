const Cell = @import("cell.zig").Cell;

const Record = struct {
    data: []Cell,

    pub fn create(cells: []Cell) Record {
        return Record{
            .data = cells,
        };
    }
};
