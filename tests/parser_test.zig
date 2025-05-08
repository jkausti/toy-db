const std = @import("std");
const print = std.debug.print;
const tst = std.testing;
const parser = @import("parser");
const Tokenizer = parser.tokenizer.Tokenizer;
const Token = parser.tokenizer.Token;
const TokenType = parser.tokenizer.TokenType;

test "Tokenizer: select" {
    const input = "SELECT * FROM table WHERE id = 10";
    var tokenizer = Tokenizer.init(input);

    const expected_tokens = [_]Token{
        Token{ .token_type = TokenType.Keyword, .value = "SELECT" },
        Token{ .token_type = TokenType.Wildcard, .value = "*" },
        Token{ .token_type = TokenType.Keyword, .value = "FROM" },
        Token{ .token_type = TokenType.Identifier, .value = "table" },
        Token{ .token_type = TokenType.Keyword, .value = "WHERE" },
        Token{ .token_type = TokenType.Identifier, .value = "id" },
        Token{ .token_type = TokenType.Operator, .value = "=" },
        Token{ .token_type = TokenType.Literal, .value = "10" },
        Token{ .token_type = TokenType.EndOfFile, .value = "" },
    };

    var index: usize = 0;
    while (true) {
        const token = tokenizer.nextToken() orelse break;
        if (token.token_type == TokenType.EndOfFile) {
            break;
        }
        try std.testing.expectEqual(expected_tokens[index].token_type, token.token_type);
        try std.testing.expectEqualStrings(expected_tokens[index].value, token.value);
        index += 1;
    }
}

test "Tokenizer: create table" {
    const input = "CREATE TABLE users (id INT, name TEXT)";
    var tokenizer = Tokenizer.init(input);

    const expected_tokens = [_]Token{
        Token{ .token_type = TokenType.Keyword, .value = "CREATE" },
        Token{ .token_type = TokenType.Keyword, .value = "TABLE" },
        Token{ .token_type = TokenType.Identifier, .value = "users" },
        Token{ .token_type = TokenType.Operator, .value = "(" },
        Token{ .token_type = TokenType.Identifier, .value = "id" },
        Token{ .token_type = TokenType.Identifier, .value = "INT" },
        Token{ .token_type = TokenType.Operator, .value = "," },
        Token{ .token_type = TokenType.Identifier, .value = "name" },
        Token{ .token_type = TokenType.Identifier, .value = "TEXT" },
        Token{ .token_type = TokenType.Operator, .value = ")" },
        Token{ .token_type = TokenType.EndOfFile, .value = "" },
    };

    var index: usize = 0;
    while (true) {
        const token = tokenizer.nextToken() orelse break;
        if (token.token_type == TokenType.EndOfFile) {
            break;
        }
        try std.testing.expectEqual(expected_tokens[index].token_type, token.token_type);
        try std.testing.expectEqualStrings(expected_tokens[index].value, token.value);
        index += 1;
    }
}
