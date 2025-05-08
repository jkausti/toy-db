const std = @import("std");

pub const TokenType = enum {
    Identifier,
    Keyword,
    Operator,
    Literal,
    Whitespace,
    Wildcard,
    EndOfFile,
};

pub const Token = struct {
    token_type: TokenType,
    value: []const u8,
};

const keywords = [_][]const u8{
    "SELECT", "FROM", "WHERE",  "INSERT", "UPDATE", "DELETE", "CREATE", "DROP", "ALTER",
    "TABLE",  "INTO", "VALUES", "SET",    "AND",    "OR",     "NOT",    "NULL", "IS",
    "IN",     "LIKE",
};

fn isKeyword(value: []const u8) bool {
    for (keywords) |keyword| {
        if (std.mem.eql(u8, keyword, value)) {
            return true;
        }
    }
    return false;
}

pub const Tokenizer = struct {
    input: []const u8,
    position: usize,

    pub fn init(input: []const u8) Tokenizer {
        return Tokenizer{
            .input = input,
            .position = 0,
        };
    }

    pub fn nextToken(self: *Tokenizer) ?Token {
        while (self.position < self.input.len) {
            const c = self.input[self.position];
            self.position += 1;

            if (std.ascii.isWhitespace(c)) {
                continue;
            }

            if (std.ascii.isAlphabetic(c)) {
                return self.readIdentifier();
            }

            if (std.ascii.isDigit(c)) {
                return self.readLiteral();
            }

            // Handle wildcard
            if (c == '*') {
                return Token{
                    .token_type = TokenType.Wildcard,
                    .value = self.input[self.position - 1 .. self.position],
                };
            }

            // Handle operators and other single-character tokens
            return Token{
                .token_type = TokenType.Operator,
                .value = self.input[self.position - 1 .. self.position],
            };
        }

        return Token{
            .token_type = TokenType.EndOfFile,
            .value = "",
        };
    }

    fn readIdentifier(self: *Tokenizer) Token {
        const start = self.position - 1;
        while (self.position < self.input.len and std.ascii.isAlphabetic(self.input[self.position])) {
            self.position += 1;
        }
        const value = self.input[start..self.position];
        var token_type = TokenType.Identifier;

        if (isKeyword(value)) {
            token_type = TokenType.Keyword;
        }
        return Token{
            .token_type = token_type,
            .value = value,
        };
    }

    fn readLiteral(self: *Tokenizer) Token {
        const start = self.position - 1;
        while (self.position < self.input.len and std.ascii.isDigit(self.input[self.position])) {
            self.position += 1;
        }
        return Token{
            .token_type = TokenType.Literal,
            .value = self.input[start..self.position],
        };
    }
};
