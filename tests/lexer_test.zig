const std = @import("std");
const testing = std.testing;
const Lexer = @import("lexer.zig").Lexer;
const TokenType = @import("token.zig").TokenType;

test "lexer: tokenize simple variable declaration" {
    const allocator = testing.allocator;
    const source = "make x: int = 42;";

    var lexer = Lexer.init(allocator, source);

    // make
    var tok = lexer.nextToken();
    try testing.expectEqual(TokenType.MAKE, tok.type);
    try testing.expectEqualStrings("make", tok.lexeme);

    // x
    tok = lexer.nextToken();
    try testing.expectEqual(TokenType.IDENTIFIER, tok.type);
    try testing.expectEqualStrings("x", tok.lexeme);

    // :
    tok = lexer.nextToken();
    try testing.expectEqual(TokenType.COLON, tok.type);

    // int
    tok = lexer.nextToken();
    try testing.expectEqual(TokenType.TYPE_INT, tok.type);

    // =
    tok = lexer.nextToken();
    try testing.expectEqual(TokenType.ASSIGN, tok.type);

    // 42
    tok = lexer.nextToken();
    try testing.expectEqual(TokenType.INTEGER, tok.type);
    try testing.expectEqualStrings("42", tok.lexeme);

    // ;
    tok = lexer.nextToken();
    try testing.expectEqual(TokenType.SEMICOLON, tok.type);

    // EOF
    tok = lexer.nextToken();
    try testing.expectEqual(TokenType.EOF, tok.type);
}

test "lexer: tokenize constant declaration with seal" {
    const allocator = testing.allocator;
    const source = "seal PI: float = 3.14;";

    var lexer = Lexer.init(allocator, source);

    var tok = lexer.nextToken();
    try testing.expectEqual(TokenType.SEAL, tok.type);

    tok = lexer.nextToken();
    try testing.expectEqual(TokenType.IDENTIFIER, tok.type);
    try testing.expectEqualStrings("PI", tok.lexeme);

    tok = lexer.nextToken();
    try testing.expectEqual(TokenType.COLON, tok.type);

    tok = lexer.nextToken();
    try testing.expectEqual(TokenType.TYPE_FLOAT, tok.type);

    tok = lexer.nextToken();
    try testing.expectEqual(TokenType.ASSIGN, tok.type);

    tok = lexer.nextToken();
    try testing.expectEqual(TokenType.FLOAT, tok.type);
    try testing.expectEqualStrings("3.14", tok.lexeme);
}

test "lexer: tokenize string literal" {
    const allocator = testing.allocator;
    const source = "make msg: string = \"Hello, World!\";";

    var lexer = Lexer.init(allocator, source);

    // Skip to string
    _ = lexer.nextToken(); // make
    _ = lexer.nextToken(); // msg
    _ = lexer.nextToken(); // :
    _ = lexer.nextToken(); // string
    _ = lexer.nextToken(); // =

    const tok = lexer.nextToken();
    try testing.expectEqual(TokenType.STRING, tok.type);
    try testing.expectEqualStrings("Hello, World!", tok.lexeme);
}

test "lexer: tokenize operators" {
    const allocator = testing.allocator;
    const source = "+ - * / == != < > <= >=";

    var lexer = Lexer.init(allocator, source);

    const expected = [_]TokenType{
        .PLUS, .MINUS, .STAR, .SLASH,
        .EQ, .NEQ, .LT, .GT, .LTE, .GTE,
    };

    for (expected) |expected_type| {
        const tok = lexer.nextToken();
        try testing.expectEqual(expected_type, tok.type);
    }
}

test "lexer: skip whitespace and comments" {
    const allocator = testing.allocator;
    const source =
        \\// This is a comment
        \\make x: int = 5; // another comment
        \\
        \\make y: int = 10;
    ;

    var lexer = Lexer.init(allocator, source);

    // Should skip comment and whitespace
    var tok = lexer.nextToken();
    try testing.expectEqual(TokenType.MAKE, tok.type);

    // Skip to second make
    _ = lexer.nextToken(); // x
    _ = lexer.nextToken(); // :
    _ = lexer.nextToken(); // int
    _ = lexer.nextToken(); // =
    _ = lexer.nextToken(); // 5
    _ = lexer.nextToken(); // ;

    tok = lexer.nextToken();
    try testing.expectEqual(TokenType.MAKE, tok.type);
}

test "lexer: tokenize if statement" {
    const allocator = testing.allocator;
    const source = "if x > 5 { print(x); }";

    var lexer = Lexer.init(allocator, source);

    var tok = lexer.nextToken();
    try testing.expectEqual(TokenType.IF, tok.type);

    tok = lexer.nextToken();
    try testing.expectEqual(TokenType.IDENTIFIER, tok.type);

    tok = lexer.nextToken();
    try testing.expectEqual(TokenType.GT, tok.type);

    tok = lexer.nextToken();
    try testing.expectEqual(TokenType.INTEGER, tok.type);

    tok = lexer.nextToken();
    try testing.expectEqual(TokenType.LBRACE, tok.type);

    tok = lexer.nextToken();
    try testing.expectEqual(TokenType.PRINT, tok.type);
}

test "lexer: tokenize boolean literals" {
    const allocator = testing.allocator;
    const source = "make flag: bool = true;";

    var lexer = Lexer.init(allocator, source);

    // Skip to true
    _ = lexer.nextToken(); // make
    _ = lexer.nextToken(); // flag
    _ = lexer.nextToken(); // :
    _ = lexer.nextToken(); // bool
    _ = lexer.nextToken(); // =

    const tok = lexer.nextToken();
    try testing.expectEqual(TokenType.TRUE, tok.type);
}

test "lexer: handle line and column numbers" {
    const allocator = testing.allocator;
    const source =
        \\make x: int = 5;
        \\make y: int = 10;
    ;

    var lexer = Lexer.init(allocator, source);

    var tok = lexer.nextToken();
    try testing.expectEqual(@as(usize, 1), tok.line);

    // Skip to second line
    while (tok.type != .EOF and tok.line == 1) {
        tok = lexer.nextToken();
    }

    try testing.expectEqual(@as(usize, 2), tok.line);
}
