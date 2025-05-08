pub const Type = enum {
    // Keywords
    Select,
    From,

    // Select Operators
    All,

    // Delimiters
    Semicolon,
    Comma,
    Dot,

    // Identifiers and literals
    Identifier,
    String,
    EndOfFile,
};

pub const Token = struct {
    typ: Type,
    start: usize,
    end: usize,
};
