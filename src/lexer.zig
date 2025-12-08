const std = @import("std");
const token = @import("token.zig");
const Token = token.Token;
const TokenType = token.TokenType;

/// Lexer for Boemia Script
pub const Lexer = struct {
    source: []const u8,
    position: usize,
    read_position: usize,
    ch: u8,
    line: usize,
    column: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, source: []const u8) Lexer {
        var lexer = Lexer{
            .source = source,
            .position = 0,
            .read_position = 0,
            .ch = 0,
            .line = 1,
            .column = 0,
            .allocator = allocator,
        };
        lexer.readChar();
        return lexer;
    }

    fn readChar(self: *Lexer) void {
        if (self.read_position >= self.source.len) {
            self.ch = 0;
        } else {
            self.ch = self.source[self.read_position];
        }
        self.position = self.read_position;
        self.read_position += 1;
        self.column += 1;
    }

    fn peekChar(self: *Lexer) u8 {
        if (self.read_position >= self.source.len) {
            return 0;
        }
        return self.source[self.read_position];
    }

    fn skipWhitespace(self: *Lexer) void {
        while (self.ch == ' ' or self.ch == '\t' or self.ch == '\n' or self.ch == '\r') {
            if (self.ch == '\n') {
                self.line += 1;
                self.column = 0;
            }
            self.readChar();
        }
    }

    fn skipComment(self: *Lexer) void {
        // Skip single-line comments //
        if (self.ch == '/' and self.peekChar() == '/') {
            while (self.ch != '\n' and self.ch != 0) {
                self.readChar();
            }
        }
    }

    fn readIdentifier(self: *Lexer) []const u8 {
        const start = self.position;
        while (isLetter(self.ch) or isDigit(self.ch) or self.ch == '_') {
            self.readChar();
        }
        return self.source[start..self.position];
    }

    fn readNumber(self: *Lexer) Token {
        const start = self.position;
        const start_column = self.column;
        var is_float = false;

        while (isDigit(self.ch)) {
            self.readChar();
        }

        // Check for decimal point
        if (self.ch == '.' and isDigit(self.peekChar())) {
            is_float = true;
            self.readChar(); // consume '.'
            while (isDigit(self.ch)) {
                self.readChar();
            }
        }

        const lexeme = self.source[start..self.position];
        const token_type = if (is_float) TokenType.FLOAT else TokenType.INTEGER;
        return Token.init(token_type, lexeme, self.line, start_column);
    }

    fn readString(self: *Lexer) Token {
        const start_column = self.column;
        self.readChar(); // consume opening "

        const start = self.position;
        while (self.ch != '"' and self.ch != 0) {
            if (self.ch == '\n') {
                self.line += 1;
                self.column = 0;
            }
            self.readChar();
        }

        if (self.ch == 0) {
            return Token.init(.ILLEGAL, "unterminated string", self.line, start_column);
        }

        const lexeme = self.source[start..self.position];
        self.readChar(); // consume closing "
        return Token.init(.STRING, lexeme, self.line, start_column);
    }

    pub fn nextToken(self: *Lexer) Token {
        self.skipWhitespace();
        self.skipComment();
        self.skipWhitespace();

        const tok_column = self.column;
        const tok_line = self.line;

        const tok = switch (self.ch) {
            '+' => blk: {
                self.readChar();
                break :blk Token.init(.PLUS, "+", tok_line, tok_column);
            },
            '-' => blk: {
                self.readChar();
                break :blk Token.init(.MINUS, "-", tok_line, tok_column);
            },
            '*' => blk: {
                self.readChar();
                break :blk Token.init(.STAR, "*", tok_line, tok_column);
            },
            '/' => blk: {
                self.readChar();
                break :blk Token.init(.SLASH, "/", tok_line, tok_column);
            },
            '=' => blk: {
                if (self.peekChar() == '=') {
                    self.readChar();
                    self.readChar();
                    break :blk Token.init(.EQ, "==", tok_line, tok_column);
                }
                self.readChar();
                break :blk Token.init(.ASSIGN, "=", tok_line, tok_column);
            },
            '!' => blk: {
                if (self.peekChar() == '=') {
                    self.readChar();
                    self.readChar();
                    break :blk Token.init(.NEQ, "!=", tok_line, tok_column);
                }
                self.readChar();
                break :blk Token.init(.ILLEGAL, "!", tok_line, tok_column);
            },
            '<' => blk: {
                if (self.peekChar() == '=') {
                    self.readChar();
                    self.readChar();
                    break :blk Token.init(.LTE, "<=", tok_line, tok_column);
                }
                self.readChar();
                break :blk Token.init(.LT, "<", tok_line, tok_column);
            },
            '>' => blk: {
                if (self.peekChar() == '=') {
                    self.readChar();
                    self.readChar();
                    break :blk Token.init(.GTE, ">=", tok_line, tok_column);
                }
                self.readChar();
                break :blk Token.init(.GT, ">", tok_line, tok_column);
            },
            '(' => blk: {
                self.readChar();
                break :blk Token.init(.LPAREN, "(", tok_line, tok_column);
            },
            ')' => blk: {
                self.readChar();
                break :blk Token.init(.RPAREN, ")", tok_line, tok_column);
            },
            '{' => blk: {
                self.readChar();
                break :blk Token.init(.LBRACE, "{", tok_line, tok_column);
            },
            '}' => blk: {
                self.readChar();
                break :blk Token.init(.RBRACE, "}", tok_line, tok_column);
            },
            ';' => blk: {
                self.readChar();
                break :blk Token.init(.SEMICOLON, ";", tok_line, tok_column);
            },
            ':' => blk: {
                self.readChar();
                break :blk Token.init(.COLON, ":", tok_line, tok_column);
            },
            ',' => blk: {
                self.readChar();
                break :blk Token.init(.COMMA, ",", tok_line, tok_column);
            },
            '"' => self.readString(),
            0 => Token.init(.EOF, "", tok_line, tok_column),
            else => blk: {
                if (isLetter(self.ch)) {
                    const ident = self.readIdentifier();
                    const tok_type = token.lookupIdentifier(ident);
                    break :blk Token.init(tok_type, ident, tok_line, tok_column);
                } else if (isDigit(self.ch)) {
                    break :blk self.readNumber();
                } else {
                    const lexeme = self.source[self.position .. self.position + 1];
                    self.readChar();
                    break :blk Token.init(.ILLEGAL, lexeme, tok_line, tok_column);
                }
            },
        };

        return tok;
    }
};

fn isLetter(ch: u8) bool {
    return (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or ch == '_';
}

fn isDigit(ch: u8) bool {
    return ch >= '0' and ch <= '9';
}
