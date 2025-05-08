// const std = @import("std");
// const Token = @import("token.zig").Token;
// const Type = @import("token.zig").Type;
//
// const Allocator = std.mem.Allocator;
//
// pub const Tokenizer = struct {
//     allocator: *Allocator,
//
//     pub fn tokenize(self: Tokenizer, input: []const u8) ![]Token {
//         var start = 0;
//         var end = 0;
//
//         while (end < input.len) {
//             const c = input[end];
//
//             // Skip whitespace
//             if (c == ' ' or c == '\n' or c == '\t') {
//                 end += 1;
//                 continue;
//             }
//
//             // Check for keywords
//
//             // Check for delimiters
//             if (c == ';') {
//                 tokens.append(Token{ .typ = Type.Semicolon, .start = start, .end = end }) catch {};
//                 start = end + 1;
//                 end += 1;
//                 continue;
//             }
//
//             // Check for * operator
//             if (c == '*') {
//                 tokens.append(Token{ .typ = Type.All, .start = start, .end = end }) catch {};
//                 start = end + 1;
//                 end += 1;
//                 continue;
//             }
//
//             // Check for dot operator
//             if (c == '.') {
//                 tokens.append(Token{ .typ = Type.Dot, .start = start, .end = end + 1 }) catch {};
//                 start = end + 1;
//                 end += 1;
//                 continue;
//             }
//
//             // Check for identifiers and literals
//             if (std.ascii.isAlpha(c)) {
//                 while (end < input.len and std.ascii.isAlpha(input[end])) {
//                     end += 1;
//                 }
//                 if (std.mem.eql(u8, input[start..end], "SELECT")) {
//                     tokens.append(Token{ .typ = Type.Select, .start = start, .end = end }) catch {};
//                     start = end + 1;
//                     end += 1;
//                     continue;
//                 } else if (std.mem.eql(u8, input[start..end], "FROM")) {
//                     tokens.append(Token{ .typ = Type.From, .start = start, .end = end }) catch {};
//                     start = end + 1;
//                     end += 1;
//                     continue;
//                 }
//                 tokens.append(Token{ .typ = Type.Identifier, .start = start, .end = end }) catch {};
//                 start = end + 1;
//                 continue;
//             }
//
//             // If we reach here, we have an unknown character
//             return error.UnknownCharacter;
//         }
//
//         return tokens;
//     }
// };
