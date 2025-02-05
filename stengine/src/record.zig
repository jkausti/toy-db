

const Table = struct {
    columns: []Column,
    records: []Record,
}



const Record = struct {
    column_metadata: *Column,
    data: []Cell,
};


