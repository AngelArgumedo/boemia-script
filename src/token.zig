const std = @import("std");

/// Token types for Boemia Script
pub const TokenType = enum {
    // Literals
    INTEGER,
    FLOAT,
    STRING,
    TRUE,
    FALSE,

    // Identifiers and keywords
    IDENTIFIER,
    MAKE, // variable declaration
    SEAL, // constant declaration
    FN, // function
    RETURN,
    IF,
    ELSE,
    WHILE,
    FOR,
    PRINT,

    // Types
    TYPE_INT,
    TYPE_FLOAT,
    TYPE_STRING,
    TYPE_BOOL,

    // Operators
    PLUS, // +
    MINUS, // -
    STAR, // *
    SLASH, // /
    ASSIGN, // =
    EQ, // ==
    NEQ, // !=
    LT, // <
    GT, // >
    LTE, // <=
    GTE, // >=

    // Delimiters
    LPAREN, // (
    RPAREN, // )
    LBRACE, // {
    RBRACE, // }
    SEMICOLON, // ;
    COLON, // :
    COMMA, // ,

    // Special
    EOF,
    ILLEGAL,
};

/// Token structure
pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    line: usize,
    column: usize,

    pub fn init(token_type: TokenType, lexeme: []const u8, line: usize, column: usize) Token {
        return Token{
            .type = token_type,
            .lexeme = lexeme,
            .line = line,
            .column = column,
        };
    }

    pub fn format(self: Token, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("Token({s}, \"{s}\", {}:{})", .{ @tagName(self.type), self.lexeme, self.line, self.column });
    }
};

/// Keywords map
pub const keywords = std.ComptimeStringMap(TokenType, .{
    .{ "make", .MAKE },
    .{ "seal", .SEAL },
    .{ "fn", .FN },
    .{ "return", .RETURN },
    .{ "if", .IF },
    .{ "else", .ELSE },
    .{ "while", .WHILE },
    .{ "for", .FOR },
    .{ "print", .PRINT },
    .{ "true", .TRUE },
    .{ "false", .FALSE },
    .{ "int", .TYPE_INT },
    .{ "float", .TYPE_FLOAT },
    .{ "string", .TYPE_STRING },
    .{ "bool", .TYPE_BOOL },
});

pub fn lookupIdentifier(ident: []const u8) TokenType {
    if (keywords.get(ident)) |token_type| {
        return token_type;
    }
    return .IDENTIFIER;
}
