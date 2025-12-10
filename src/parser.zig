const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const ast = @import("ast.zig");
const Stmt = ast.Stmt;
const Expr = ast.Expr;
const DataType = ast.DataType;
const BinaryOp = ast.BinaryOp;
const Program = ast.Program;

pub const ParseError = error{
    UnexpectedToken,
    ExpectedExpression,
    ExpectedStatement,
    InvalidType,
    OutOfMemory,
};

pub const Parser = struct {
    lexer: *Lexer,
    current_token: Token,
    peek_token: Token,
    allocator: std.mem.Allocator,
    errors: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator, lexer: *Lexer) !Parser {
        var parser = Parser{
            .lexer = lexer,
            .current_token = undefined,
            .peek_token = undefined,
            .allocator = allocator,
            .errors = std.ArrayList([]const u8).init(allocator),
        };
        parser.nextToken();
        parser.nextToken();
        return parser;
    }

    pub fn deinit(self: *Parser) void {
        self.errors.deinit();
    }

    fn nextToken(self: *Parser) void {
        self.current_token = self.peek_token;
        self.peek_token = self.lexer.nextToken();
    }

    fn expectToken(self: *Parser, token_type: TokenType) !void {
        self.nextToken(); // Advance first
        if (self.current_token.type != token_type) {
            const err = try std.fmt.allocPrint(
                self.allocator,
                "Expected {s}, got {s} at {}:{}",
                .{ @tagName(token_type), @tagName(self.current_token.type), self.current_token.line, self.current_token.column },
            );
            try self.errors.append(err);
            return ParseError.UnexpectedToken;
        }
    }

    pub fn parseProgram(self: *Parser) !Program {
        var statements = std.ArrayList(Stmt).init(self.allocator);
        errdefer statements.deinit();

        while (self.current_token.type != .EOF) {
            const stmt = self.parseStatement() catch |err| {
                // Skip to next statement on error
                while (self.current_token.type != .SEMICOLON and self.current_token.type != .EOF) {
                    self.nextToken();
                }
                if (self.current_token.type == .SEMICOLON) {
                    self.nextToken();
                }
                return err;
            };
            try statements.append(stmt);
        }

        return Program.init(self.allocator, try statements.toOwnedSlice());
    }

    fn parseStatement(self: *Parser) ParseError!Stmt {
        return switch (self.current_token.type) {
            .MAKE, .SEAL => self.parseVariableDecl(),
            .IF => self.parseIfStatement(),
            .WHILE => self.parseWhileStatement(),
            .FOR => self.parseForStatement(),
            .RETURN => self.parseReturnStatement(),
            .PRINT => self.parsePrintStatement(),
            .FN => self.parseFunctionDecl(),
            .LBRACE => self.parseBlockStatement(),
            .IDENTIFIER => blk: {
                if (self.peek_token.type == .ASSIGN) {
                    break :blk self.parseAssignment();
                }
                break :blk self.parseExpressionStatement();
            },
            else => self.parseExpressionStatement(),
        };
    }

    fn parseVariableDecl(self: *Parser) ParseError!Stmt {
        const is_const = self.current_token.type == .SEAL;
        self.nextToken(); // consume 'make' or 'seal'

        if (self.current_token.type != .IDENTIFIER) {
            return ParseError.UnexpectedToken;
        }
        const name = self.current_token.lexeme;

        try self.expectToken(.COLON);

        const data_type = DataType.fromString(self.peek_token.lexeme) orelse return ParseError.InvalidType;
        self.nextToken(); // move to type token

        try self.expectToken(.ASSIGN);
        self.nextToken(); // move to expression start

        const value = try self.parseExpression(0);

        if (self.current_token.type != .SEMICOLON) {
            return ParseError.UnexpectedToken;
        }
        self.nextToken(); // consume semicolon

        return Stmt{ .variable_decl = .{
            .name = name,
            .data_type = data_type,
            .value = value,
            .is_const = is_const,
        } };
    }

    fn parseAssignment(self: *Parser) ParseError!Stmt {
        const name = self.current_token.lexeme;
        self.nextToken(); // consume identifier
        self.nextToken(); // consume '='

        const value = try self.parseExpression(0);

        try self.expectToken(.SEMICOLON);

        return Stmt{ .assignment = .{
            .name = name,
            .value = value,
        } };
    }

    fn parseIfStatement(self: *Parser) ParseError!Stmt {
        self.nextToken(); // consume 'if'

        const condition = try self.parseExpression(0);

        try self.expectToken(.LBRACE);
        const then_block = try self.parseBlock();

        var else_block: ?[]Stmt = null;
        if (self.peek_token.type == .ELSE) {
            self.nextToken(); // consume '}'
            self.nextToken(); // consume 'else'

            if (self.peek_token.type == .IF) {
                // else if
                self.nextToken();
                const elif_stmt = try self.parseIfStatement();
                const elif_ptr = try self.allocator.create(Stmt);
                elif_ptr.* = elif_stmt;
                else_block = try self.allocator.alloc(Stmt, 1);
                else_block.?[0] = elif_ptr.*;
            } else {
                try self.expectToken(.LBRACE);
                else_block = try self.parseBlock();
            }
        } else {
            self.nextToken(); // consume '}'
        }

        const if_stmt = try self.allocator.create(Stmt.IfStmt);
        if_stmt.* = .{
            .condition = condition,
            .then_block = then_block,
            .else_block = else_block,
        };

        return Stmt{ .if_stmt = if_stmt };
    }

    fn parseWhileStatement(self: *Parser) ParseError!Stmt {
        self.nextToken(); // consume 'while'

        const condition = try self.parseExpression(0);

        try self.expectToken(.LBRACE);
        const body = try self.parseBlock();

        const while_stmt = try self.allocator.create(Stmt.WhileStmt);
        while_stmt.* = .{
            .condition = condition,
            .body = body,
        };

        self.nextToken(); // consume '}'

        return Stmt{ .while_stmt = while_stmt };
    }

    fn parseForStatement(self: *Parser) ParseError!Stmt {
        self.nextToken(); // consume 'for'

        // Parse init
        const init_stmt = try self.allocator.create(Stmt);
        init_stmt.* = try self.parseStatement();

        // Parse condition
        const condition = try self.parseExpression(0);
        try self.expectToken(.SEMICOLON);

        // Parse update
        const update_stmt = try self.allocator.create(Stmt);
        update_stmt.* = try self.parseAssignment();

        try self.expectToken(.LBRACE);
        const body = try self.parseBlock();

        const for_stmt = try self.allocator.create(Stmt.ForStmt);
        for_stmt.* = .{
            .init = init_stmt,
            .condition = condition,
            .update = update_stmt,
            .body = body,
        };

        self.nextToken(); // consume '}'

        return Stmt{ .for_stmt = for_stmt };
    }

    fn parseReturnStatement(self: *Parser) ParseError!Stmt {
        self.nextToken(); // consume 'return'

        var value: ?Expr = null;
        if (self.current_token.type != .SEMICOLON) {
            value = try self.parseExpression(0);
        }

        try self.expectToken(.SEMICOLON);

        const ret_stmt = try self.allocator.create(Stmt.ReturnStmt);
        ret_stmt.* = .{ .value = value };

        return Stmt{ .return_stmt = ret_stmt };
    }

    fn parsePrintStatement(self: *Parser) ParseError!Stmt {
        try self.expectToken(.LPAREN);
        self.nextToken(); // move to expression

        const expr = try self.parseExpression(0);

        if (self.current_token.type != .RPAREN) {
            return ParseError.UnexpectedToken;
        }
        self.nextToken(); // consume )

        if (self.current_token.type != .SEMICOLON) {
            return ParseError.UnexpectedToken;
        }
        self.nextToken(); // consume semicolon

        return Stmt{ .print_stmt = expr };
    }

    fn parseFunctionDecl(self: *Parser) ParseError!Stmt {
        self.nextToken(); // consume 'fn'

        if (self.current_token.type != .IDENTIFIER) {
            return ParseError.UnexpectedToken;
        }
        const name = self.current_token.lexeme;
        self.nextToken();

        try self.expectToken(.LPAREN);

        var params = std.ArrayList(Stmt.Parameter).init(self.allocator);
        defer params.deinit();

        while (self.current_token.type != .RPAREN) {
            if (self.current_token.type != .IDENTIFIER) {
                return ParseError.UnexpectedToken;
            }
            const param_name = self.current_token.lexeme;
            self.nextToken();

            try self.expectToken(.COLON);

            const param_type = DataType.fromString(self.current_token.lexeme) orelse return ParseError.InvalidType;
            self.nextToken();

            try params.append(.{ .name = param_name, .data_type = param_type });

            if (self.current_token.type == .COMMA) {
                self.nextToken();
            }
        }

        try self.expectToken(.RPAREN);
        try self.expectToken(.COLON);

        const return_type = DataType.fromString(self.current_token.lexeme) orelse return ParseError.InvalidType;
        self.nextToken();

        try self.expectToken(.LBRACE);
        const body = try self.parseBlock();

        const func_decl = try self.allocator.create(Stmt.FunctionDecl);
        func_decl.* = .{
            .name = name,
            .params = try params.toOwnedSlice(),
            .return_type = return_type,
            .body = body,
        };

        self.nextToken(); // consume '}'

        return Stmt{ .function_decl = func_decl };
    }

    fn parseBlockStatement(self: *Parser) ParseError!Stmt {
        try self.expectToken(.LBRACE);
        const stmts = try self.parseBlock();
        self.nextToken(); // consume '}'
        return Stmt{ .block = stmts };
    }

    fn parseBlock(self: *Parser) ParseError![]Stmt {
        var statements = std.ArrayList(Stmt).init(self.allocator);
        errdefer statements.deinit();

        while (self.current_token.type != .RBRACE and self.current_token.type != .EOF) {
            const stmt = try self.parseStatement();
            try statements.append(stmt);
        }

        return statements.toOwnedSlice();
    }

    fn parseExpressionStatement(self: *Parser) ParseError!Stmt {
        const expr = try self.parseExpression(0);
        try self.expectToken(.SEMICOLON);
        return Stmt{ .expr_stmt = expr };
    }

    fn parseExpression(self: *Parser, min_precedence: u8) ParseError!Expr {
        var left = try self.parsePrimary();

        while (true) {
            const op = self.getInfixOp() orelse break;
            const precedence = self.getPrecedence(op);
            if (precedence < min_precedence) break;

            self.nextToken();
            const right = try self.parseExpression(precedence + 1);

            const binary = try self.allocator.create(Expr.BinaryExpr);
            binary.* = .{
                .left = left,
                .operator = op,
                .right = right,
            };
            left = Expr{ .binary = binary };
        }

        return left;
    }

    fn parsePrimary(self: *Parser) ParseError!Expr {
        return switch (self.current_token.type) {
            .INTEGER => blk: {
                const val = std.fmt.parseInt(i64, self.current_token.lexeme, 10) catch return ParseError.ExpectedExpression;
                self.nextToken();
                break :blk Expr{ .integer = val };
            },
            .FLOAT => blk: {
                const val = std.fmt.parseFloat(f64, self.current_token.lexeme) catch return ParseError.ExpectedExpression;
                self.nextToken();
                break :blk Expr{ .float = val };
            },
            .STRING => blk: {
                const val = self.current_token.lexeme;
                self.nextToken();
                break :blk Expr{ .string = val };
            },
            .TRUE => blk: {
                self.nextToken();
                break :blk Expr{ .boolean = true };
            },
            .FALSE => blk: {
                self.nextToken();
                break :blk Expr{ .boolean = false };
            },
            .IDENTIFIER => blk: {
                const name = self.current_token.lexeme;
                self.nextToken();

                // Check for function call
                if (self.current_token.type == .LPAREN) {
                    self.nextToken();
                    var args = std.ArrayList(Expr).init(self.allocator);
                    defer args.deinit();

                    while (self.current_token.type != .RPAREN) {
                        const arg = try self.parseExpression(0);
                        try args.append(arg);

                        if (self.current_token.type == .COMMA) {
                            self.nextToken();
                        }
                    }

                    try self.expectToken(.RPAREN);

                    const call = try self.allocator.create(Expr.CallExpr);
                    call.* = .{
                        .name = name,
                        .args = try args.toOwnedSlice(),
                    };
                    break :blk Expr{ .call = call };
                }

                break :blk Expr{ .identifier = name };
            },
            .LPAREN => blk: {
                self.nextToken();
                const expr = try self.parseExpression(0);
                try self.expectToken(.RPAREN);
                break :blk expr;
            },
            .MINUS => blk: {
                self.nextToken();
                const operand = try self.parsePrimary();
                const unary = try self.allocator.create(Expr.UnaryExpr);
                unary.* = .{
                    .operator = .NEG,
                    .operand = operand,
                };
                break :blk Expr{ .unary = unary };
            },
            else => ParseError.ExpectedExpression,
        };
    }

    fn getInfixOp(self: *Parser) ?BinaryOp {
        return switch (self.current_token.type) {
            .PLUS => .ADD,
            .MINUS => .SUB,
            .STAR => .MUL,
            .SLASH => .DIV,
            .EQ => .EQ,
            .NEQ => .NEQ,
            .LT => .LT,
            .GT => .GT,
            .LTE => .LTE,
            .GTE => .GTE,
            else => null,
        };
    }

    fn getPrecedence(self: *Parser, op: BinaryOp) u8 {
        _ = self;
        return switch (op) {
            .MUL, .DIV => 6,
            .ADD, .SUB => 5,
            .LT, .GT, .LTE, .GTE => 4,
            .EQ, .NEQ => 3,
        };
    }
};
