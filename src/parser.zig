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
            .errors = .empty,
        };
        parser.nextToken();
        parser.nextToken();
        return parser;
    }

    pub fn deinit(self: *Parser) void {
        self.errors.deinit(self.allocator);
    }

    fn nextToken(self: *Parser) void {
        self.current_token = self.peek_token;
        self.peek_token = self.lexer.nextToken();
    }

    fn expectToken(self: *Parser, token_type: TokenType) !void {
        if (self.peek_token.type != token_type) {
            const err = try std.fmt.allocPrint(
                self.allocator,
                "Expected {s}, got {s} at {}:{}",
                .{ @tagName(token_type), @tagName(self.peek_token.type), self.peek_token.line, self.peek_token.column },
            );
            try self.errors.append(self.allocator, err);
            return ParseError.UnexpectedToken;
        }
        self.nextToken(); // Advance after checking
    }

    // Parse data types including array syntax: int, float, [int], [[int]], etc.
    // Expects type to be in peek_token when called
    // After calling, peek_token will be the token after the type
    fn parseDataType(self: *Parser) ParseError!DataType {
        // Check for array syntax: [T]
        if (self.peek_token.type == .LBRACKET) {
            self.nextToken(); // consume current, move to '['
            // Now current = '[', peek = element type or another '['

            // Recursively parse element type
            const element_type = try self.parseDataType();
            // Now peek should be ']'

            if (self.peek_token.type != .RBRACKET) {
                const err = try std.fmt.allocPrint(
                    self.allocator,
                    "Expected ']', got {s} at {}:{}",
                    .{ @tagName(self.peek_token.type), self.peek_token.line, self.peek_token.column },
                );
                try self.errors.append(self.allocator, err);
                return ParseError.UnexpectedToken;
            }
            self.nextToken(); // consume ']'

            // Create DataType.ARRAY
            const elem_type_ptr = try self.allocator.create(DataType);
            elem_type_ptr.* = element_type;

            const array_type = try self.allocator.create(DataType.ArrayType);
            array_type.* = .{
                .element_type = elem_type_ptr,
                .allocator = self.allocator,
            };

            return DataType{ .ARRAY = array_type };
        }

        // Simple type: int, float, string, bool, void
        const data_type = try DataType.fromString(self.allocator, self.peek_token.lexeme) orelse {
            const err = try std.fmt.allocPrint(
                self.allocator,
                "Invalid type '{s}' at {}:{}",
                .{ self.peek_token.lexeme, self.peek_token.line, self.peek_token.column },
            );
            try self.errors.append(self.allocator, err);
            return ParseError.InvalidType;
        };

        self.nextToken(); // consume type token
        return data_type;
    }

    pub fn parseProgram(self: *Parser) !Program {
        var statements: std.ArrayList(Stmt) = .empty;
        errdefer statements.deinit(self.allocator);

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
            try statements.append(self.allocator, stmt);
        }

        return Program.init(self.allocator, try statements.toOwnedSlice(self.allocator));
    }

    fn parseStatement(self: *Parser) ParseError!Stmt {
        return switch (self.current_token.type) {
            .LET, .CONST => self.parseVariableDecl(),
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
        const is_const = self.current_token.type == .CONST;
        self.nextToken(); // consume 'let' or 'const'

        if (self.current_token.type != .IDENTIFIER) {
            return ParseError.UnexpectedToken;
        }
        const name = self.current_token.lexeme;

        try self.expectToken(.COLON);

        const data_type = try self.parseDataType();

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

        // After parseExpression, current_token is at SEMICOLON
        if (self.current_token.type != .SEMICOLON) {
            return ParseError.UnexpectedToken;
        }
        self.nextToken(); // consume SEMICOLON

        return Stmt{ .assignment = .{
            .name = name,
            .value = value,
        } };
    }

    fn parseIfStatement(self: *Parser) ParseError!Stmt {
        self.nextToken(); // consume 'if'

        const condition = try self.parseExpression(0);

        // After parseExpression, current_token is at LBRACE
        if (self.current_token.type != .LBRACE) {
            return ParseError.UnexpectedToken;
        }
        self.nextToken(); // consume LBRACE
        const then_block = try self.parseBlock();

        var else_block: ?[]Stmt = null;
        if (self.peek_token.type == .ELSE) {
            self.nextToken(); // consume '}'
            self.nextToken(); // consume 'else'

            // After consuming 'else', current_token is at next token (either 'if' or '{')
            if (self.current_token.type == .IF) {
                // else if - recursively parse as another if statement
                const elif_stmt = try self.parseIfStatement();
                // Create a single-element slice and copy the elif statement directly
                else_block = try self.allocator.alloc(Stmt, 1);
                else_block.?[0] = elif_stmt;
            } else if (self.current_token.type == .LBRACE) {
                // else block
                self.nextToken(); // consume LBRACE
                else_block = try self.parseBlock();
                // After parseBlock, current_token is at RBRACE, consume it
                self.nextToken(); // consume '}'
            } else {
                return ParseError.UnexpectedToken;
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

        // After parseExpression, current_token is at LBRACE
        if (self.current_token.type != .LBRACE) {
            return ParseError.UnexpectedToken;
        }
        self.nextToken(); // consume LBRACE
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

        // Parse init - special case for variable declaration without 'make'
        const init_stmt = try self.allocator.create(Stmt);
        if (self.current_token.type == .IDENTIFIER and self.peek_token.type == .COLON) {
            // Variable declaration in for loop: i: int = 0;
            const name = self.current_token.lexeme;
            self.nextToken(); // consume identifier

            if (self.current_token.type != .COLON) {
                return ParseError.UnexpectedToken;
            }

            const data_type = try self.parseDataType();

            if (self.current_token.type != .ASSIGN) {
                return ParseError.UnexpectedToken;
            }
            self.nextToken(); // consume '='

            const value = try self.parseExpression(0);

            if (self.current_token.type != .SEMICOLON) {
                return ParseError.UnexpectedToken;
            }
            self.nextToken(); // consume ';'

            init_stmt.* = Stmt{ .variable_decl = .{
                .name = name,
                .data_type = data_type,
                .value = value,
                .is_const = false,
            } };
        } else {
            init_stmt.* = try self.parseStatement();
        }

        // Parse condition
        const condition = try self.parseExpression(0);
        // After parseExpression, current_token is at SEMICOLON
        if (self.current_token.type != .SEMICOLON) {
            return ParseError.UnexpectedToken;
        }
        self.nextToken(); // consume SEMICOLON

        // Parse update (assignment without semicolon)
        const update_stmt = try self.allocator.create(Stmt);
        const update_name = self.current_token.lexeme;
        self.nextToken(); // consume identifier
        self.nextToken(); // consume '='
        const update_value = try self.parseExpression(0);
        update_stmt.* = Stmt{ .assignment = .{
            .name = update_name,
            .value = update_value,
        } };

        // After parseExpression for update, current_token is at LBRACE
        if (self.current_token.type != .LBRACE) {
            return ParseError.UnexpectedToken;
        }
        self.nextToken(); // consume LBRACE
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
            // After parseExpression, current_token is at SEMICOLON
        }

        if (self.current_token.type != .SEMICOLON) {
            return ParseError.UnexpectedToken;
        }
        self.nextToken(); // consume SEMICOLON

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

        try self.expectToken(.LPAREN); // verifies peek is LPAREN, then advances
        self.nextToken(); // move to first parameter or RPAREN

        var params: std.ArrayList(Stmt.Parameter) = .empty;
        defer params.deinit(self.allocator);

        while (self.current_token.type != .RPAREN) {
            if (self.current_token.type != .IDENTIFIER) {
                return ParseError.UnexpectedToken;
            }
            const param_name = self.current_token.lexeme;

            try self.expectToken(.COLON); // verifies peek is COLON, then advances

            const param_type = try self.parseDataType();

            try params.append(self.allocator, .{ .name = param_name, .data_type = param_type });

            if (self.current_token.type == .COMMA) {
                self.nextToken(); // consume comma
            }
        }

        // current_token is already RPAREN from the loop exit
        self.nextToken(); // consume RPAREN

        if (self.current_token.type != .COLON) {
            return ParseError.UnexpectedToken;
        }

        const return_type = try self.parseDataType();

        if (self.current_token.type != .LBRACE) {
            return ParseError.UnexpectedToken;
        }
        self.nextToken(); // consume LBRACE and move to first statement
        const body = try self.parseBlock();

        const func_decl = try self.allocator.create(Stmt.FunctionDecl);
        func_decl.* = .{
            .name = name,
            .params = try params.toOwnedSlice(self.allocator),
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
        var statements: std.ArrayList(Stmt) = .empty;
        errdefer statements.deinit(self.allocator);

        while (self.current_token.type != .RBRACE and self.current_token.type != .EOF) {
            const stmt = try self.parseStatement();
            try statements.append(self.allocator, stmt);
        }

        return statements.toOwnedSlice(self.allocator);
    }

    fn parseExpressionStatement(self: *Parser) ParseError!Stmt {
        const expr = try self.parseExpression(0);
        // After parseExpression, current_token is at SEMICOLON
        if (self.current_token.type != .SEMICOLON) {
            return ParseError.UnexpectedToken;
        }
        self.nextToken(); // consume SEMICOLON
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

                var expr = Expr{ .identifier = name };

                // Loop for chaining: arr[0][1], arr.length, arr.push(5), etc.
                while (true) {
                    if (self.current_token.type == .LBRACKET) {
                        // Index access: arr[index]
                        self.nextToken(); // consume '['
                        const index = try self.parseExpression(0);

                        if (self.current_token.type != .RBRACKET) {
                            const err = try std.fmt.allocPrint(
                                self.allocator,
                                "Expected ']', got {s} at {}:{}",
                                .{ @tagName(self.current_token.type), self.current_token.line, self.current_token.column },
                            );
                            try self.errors.append(self.allocator, err);
                            return ParseError.UnexpectedToken;
                        }
                        self.nextToken(); // consume ']'

                        const idx_access = try self.allocator.create(Expr.IndexAccess);
                        idx_access.* = .{ .array = expr, .index = index };
                        expr = Expr{ .index_access = idx_access };
                    } else if (self.current_token.type == .DOT) {
                        // Member or method access
                        self.nextToken(); // consume '.'

                        if (self.current_token.type != .IDENTIFIER) {
                            const err = try std.fmt.allocPrint(
                                self.allocator,
                                "Expected identifier after '.', got {s} at {}:{}",
                                .{ @tagName(self.current_token.type), self.current_token.line, self.current_token.column },
                            );
                            try self.errors.append(self.allocator, err);
                            return ParseError.UnexpectedToken;
                        }
                        const member_name = self.current_token.lexeme;
                        self.nextToken(); // consume identifier

                        if (self.current_token.type == .LPAREN) {
                            // Method call: arr.push(5)
                            self.nextToken(); // consume '('

                            var args: std.ArrayList(Expr) = .empty;
                            defer args.deinit(self.allocator);

                            while (self.current_token.type != .RPAREN) {
                                const arg = try self.parseExpression(0);
                                try args.append(self.allocator, arg);

                                if (self.current_token.type == .COMMA) {
                                    self.nextToken();
                                }
                            }
                            self.nextToken(); // consume ')'

                            const meth_call = try self.allocator.create(Expr.MethodCall);
                            meth_call.* = .{
                                .object = expr,
                                .method = member_name,
                                .args = try args.toOwnedSlice(self.allocator),
                            };
                            expr = Expr{ .method_call = meth_call };
                        } else {
                            // Property access: arr.length
                            const mem_access = try self.allocator.create(Expr.MemberAccess);
                            mem_access.* = .{ .object = expr, .member = member_name };
                            expr = Expr{ .member_access = mem_access };
                        }
                    } else if (self.current_token.type == .LPAREN) {
                        // Function call: func(args)
                        self.nextToken(); // consume '('
                        var args: std.ArrayList(Expr) = .empty;
                        defer args.deinit(self.allocator);

                        while (self.current_token.type != .RPAREN) {
                            const arg = try self.parseExpression(0);
                            try args.append(self.allocator, arg);

                            if (self.current_token.type == .COMMA) {
                                self.nextToken();
                            }
                        }
                        self.nextToken(); // consume ')'

                        // Extract identifier name if it's a simple identifier
                        const func_name = switch (expr) {
                            .identifier => |id| id,
                            else => {
                                const err = try std.fmt.allocPrint(
                                    self.allocator,
                                    "Cannot call non-function expression",
                                    .{},
                                );
                                try self.errors.append(self.allocator, err);
                                return ParseError.UnexpectedToken;
                            },
                        };

                        const call = try self.allocator.create(Expr.CallExpr);
                        call.* = .{
                            .name = func_name,
                            .args = try args.toOwnedSlice(self.allocator),
                        };
                        expr = Expr{ .call = call };
                        break; // Function calls don't chain further
                    } else {
                        break;
                    }
                }

                break :blk expr;
            },
            .LPAREN => blk: {
                self.nextToken();
                const expr = try self.parseExpression(0);
                try self.expectToken(.RPAREN);
                break :blk expr;
            },
            .LBRACKET => blk: {
                self.nextToken(); // consume '['

                var elements: std.ArrayList(Expr) = .empty;
                defer elements.deinit(self.allocator);

                // Check for empty array
                if (self.current_token.type == .RBRACKET) {
                    self.nextToken(); // consume ']'
                    const arr_lit = try self.allocator.create(Expr.ArrayLiteral);
                    arr_lit.* = .{
                        .elements = try elements.toOwnedSlice(self.allocator),
                        .element_type = null,
                    };
                    break :blk Expr{ .array_literal = arr_lit };
                }

                // Parse elements separated by comma
                while (true) {
                    const elem = try self.parseExpression(0);
                    try elements.append(self.allocator, elem);

                    if (self.current_token.type == .COMMA) {
                        self.nextToken();
                        continue;
                    }

                    if (self.current_token.type == .RBRACKET) {
                        self.nextToken(); // consume ']'
                        break;
                    }

                    // Unexpected token
                    const err = try std.fmt.allocPrint(
                        self.allocator,
                        "Expected ',' or ']' in array literal, got {s} at {}:{}",
                        .{ @tagName(self.current_token.type), self.current_token.line, self.current_token.column },
                    );
                    try self.errors.append(self.allocator, err);
                    return ParseError.UnexpectedToken;
                }

                const arr_lit = try self.allocator.create(Expr.ArrayLiteral);
                arr_lit.* = .{
                    .elements = try elements.toOwnedSlice(self.allocator),
                    .element_type = null,
                };
                break :blk Expr{ .array_literal = arr_lit };
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
