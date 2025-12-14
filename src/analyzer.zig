const std = @import("std");
const ast = @import("ast.zig");
const Stmt = ast.Stmt;
const Expr = ast.Expr;
const DataType = ast.DataType;
const BinaryOp = ast.BinaryOp;
const Program = ast.Program;

pub const AnalyzerError = error{
    UndefinedVariable,
    TypeMismatch,
    ConstantAssignment,
    RedeclaredVariable,
    OutOfMemory,
    InvalidOperation,
};

const Symbol = struct {
    data_type: DataType,
    is_const: bool,
};

const FunctionSignature = struct {
    return_type: DataType,
    param_types: []DataType,
};

pub const Analyzer = struct {
    allocator: std.mem.Allocator,
    symbol_table: std.StringHashMap(Symbol),
    function_table: std.StringHashMap(FunctionSignature),
    errors: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator) Analyzer {
        return Analyzer{
            .allocator = allocator,
            .symbol_table = std.StringHashMap(Symbol).init(allocator),
            .function_table = std.StringHashMap(FunctionSignature).init(allocator),
            .errors = .empty,
        };
    }

    pub fn deinit(self: *Analyzer) void {
        self.symbol_table.deinit();

        // Free function signatures
        var it = self.function_table.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.value_ptr.param_types);
        }
        self.function_table.deinit();
        for (self.errors.items) |err| {
            self.allocator.free(err);
        }
        self.errors.deinit(self.allocator);
    }

    fn typesEqual(self: *Analyzer, a: DataType, b: DataType) bool {
        const tag_a = @as(std.meta.Tag(DataType), a);
        const tag_b = @as(std.meta.Tag(DataType), b);

        if (tag_a != tag_b) return false;

        switch (a) {
            .ARRAY => |arr_a| {
                switch (b) {
                    .ARRAY => |arr_b| {
                        return typesEqual(self, arr_a.element_type.*, arr_b.element_type.*);
                    },
                    else => return false,
                }
            },
            else => return true,
        }
    }

    pub fn analyze(self: *Analyzer, program: *Program) !void {
        for (program.statements) |*stmt| {
            try self.analyzeStmt(stmt);
        }
    }

    fn analyzeStmt(self: *Analyzer, stmt: *Stmt) AnalyzerError!void {
        switch (stmt.*) {
            .variable_decl => |*decl| {
                // Check if variable already exists
                if (self.symbol_table.get(decl.name)) |_| {
                    const err = try std.fmt.allocPrint(
                        self.allocator,
                        "Variable '{s}' is already declared",
                        .{decl.name},
                    );
                    try self.errors.append(self.allocator, err);
                    return AnalyzerError.RedeclaredVariable;
                }

                const expr_type = try self.checkExpr(&decl.value);

                // Check type compatibility
                if (!self.typesEqual(expr_type, decl.data_type)) {
                    const expr_type_str = try expr_type.toString(self.allocator);
                    defer self.allocator.free(expr_type_str);
                    const decl_type_str = try decl.data_type.toString(self.allocator);
                    defer self.allocator.free(decl_type_str);
                    const err = try std.fmt.allocPrint(
                        self.allocator,
                        "Type mismatch: cannot assign {s} to {s}",
                        .{ expr_type_str, decl_type_str },
                    );
                    try self.errors.append(self.allocator, err);
                    return AnalyzerError.TypeMismatch;
                }

                try self.symbol_table.put(decl.name, Symbol{
                    .data_type = decl.data_type,
                    .is_const = decl.is_const,
                });
            },
            .assignment => |*assign| {
                const symbol = self.symbol_table.get(assign.name) orelse {
                    const err = try std.fmt.allocPrint(
                        self.allocator,
                        "Undefined variable '{s}'",
                        .{assign.name},
                    );
                    try self.errors.append(self.allocator, err);
                    return AnalyzerError.UndefinedVariable;
                };

                if (symbol.is_const) {
                    const err = try std.fmt.allocPrint(
                        self.allocator,
                        "Cannot assign to constant '{s}'",
                        .{assign.name},
                    );
                    try self.errors.append(self.allocator, err);
                    return AnalyzerError.ConstantAssignment;
                }

                const expr_type = try self.checkExpr(&assign.value);
                if (!self.typesEqual(expr_type, symbol.data_type)) {
                    const expr_type_str = try expr_type.toString(self.allocator);
                    defer self.allocator.free(expr_type_str);
                    const symbol_type_str = try symbol.data_type.toString(self.allocator);
                    defer self.allocator.free(symbol_type_str);
                    const err = try std.fmt.allocPrint(
                        self.allocator,
                        "Type mismatch: cannot assign {s} to {s}",
                        .{ expr_type_str, symbol_type_str },
                    );
                    try self.errors.append(self.allocator, err);
                    return AnalyzerError.TypeMismatch;
                }
            },
            .if_stmt => |if_stmt| {
                const cond_type = try self.checkExpr(&if_stmt.condition);
                if (cond_type != .BOOL) {
                    const cond_type_str = try cond_type.toString(self.allocator);
                    defer self.allocator.free(cond_type_str);
                    const err = try std.fmt.allocPrint(
                        self.allocator,
                        "If condition must be bool, got {s}",
                        .{cond_type_str},
                    );
                    try self.errors.append(self.allocator, err);
                    return AnalyzerError.TypeMismatch;
                }

                // Save variables declared in then block so we can remove them after
                var then_vars: std.ArrayList([]const u8) = .empty;
                defer then_vars.deinit(self.allocator);

                const then_vars_start_count = self.symbol_table.count();
                for (if_stmt.then_block) |*s| {
                    try self.analyzeStmt(s);
                }

                // Collect variables declared in then block
                var it = self.symbol_table.iterator();
                var count: usize = 0;
                while (it.next()) |entry| : (count += 1) {
                    if (count >= then_vars_start_count) {
                        try then_vars.append(self.allocator, entry.key_ptr.*);
                    }
                }

                // Remove then block variables before analyzing else block
                for (then_vars.items) |var_name| {
                    _ = self.symbol_table.remove(var_name);
                }

                if (if_stmt.else_block) |else_block| {
                    const else_vars_start_count = self.symbol_table.count();
                    for (else_block) |*s| {
                        try self.analyzeStmt(s);
                    }

                    // Remove else block variables after analyzing
                    var else_it = self.symbol_table.iterator();
                    var else_count: usize = 0;
                    var else_vars: std.ArrayList([]const u8) = .empty;
                    defer else_vars.deinit(self.allocator);

                    while (else_it.next()) |entry| : (else_count += 1) {
                        if (else_count >= else_vars_start_count) {
                            try else_vars.append(self.allocator, entry.key_ptr.*);
                        }
                    }

                    for (else_vars.items) |var_name| {
                        _ = self.symbol_table.remove(var_name);
                    }
                }
            },
            .while_stmt => |while_stmt| {
                const cond_type = try self.checkExpr(&while_stmt.condition);
                if (cond_type != .BOOL) {
                    const cond_type_str = try cond_type.toString(self.allocator);
                    defer self.allocator.free(cond_type_str);
                    const err = try std.fmt.allocPrint(
                        self.allocator,
                        "While condition must be bool, got {s}",
                        .{cond_type_str},
                    );
                    try self.errors.append(self.allocator, err);
                    return AnalyzerError.TypeMismatch;
                }

                for (while_stmt.body) |*s| {
                    try self.analyzeStmt(s);
                }
            },
            .for_stmt => |for_stmt| {
                if (for_stmt.init) |init_stmt| {
                    try self.analyzeStmt(init_stmt);
                }

                const cond_type = try self.checkExpr(&for_stmt.condition);
                if (cond_type != .BOOL) {
                    const cond_type_str = try cond_type.toString(self.allocator);
                    defer self.allocator.free(cond_type_str);
                    const err = try std.fmt.allocPrint(
                        self.allocator,
                        "For condition must be bool, got {s}",
                        .{cond_type_str},
                    );
                    try self.errors.append(self.allocator, err);
                    return AnalyzerError.TypeMismatch;
                }

                if (for_stmt.update) |update_stmt| {
                    try self.analyzeStmt(update_stmt);
                }

                for (for_stmt.body) |*s| {
                    try self.analyzeStmt(s);
                }
            },
            .return_stmt => |ret_stmt| {
                if (ret_stmt.value) |*val| {
                    _ = try self.checkExpr(val);
                }
            },
            .expr_stmt => |*expr| {
                _ = try self.checkExpr(expr);
            },
            .print_stmt => |*expr| {
                _ = try self.checkExpr(expr);
            },
            .block => |stmts| {
                for (stmts) |*s| {
                    try self.analyzeStmt(s);
                }
            },
            .function_decl => |func| {
                // Register function in function table
                var param_types = try self.allocator.alloc(DataType, func.params.len);
                for (func.params, 0..) |param, i| {
                    param_types[i] = param.data_type;
                }

                try self.function_table.put(func.name, FunctionSignature{
                    .return_type = func.return_type,
                    .param_types = param_types,
                });

                // Add parameters to symbol table
                for (func.params) |param| {
                    try self.symbol_table.put(param.name, Symbol{
                        .data_type = param.data_type,
                        .is_const = false,
                    });
                }

                for (func.body) |*s| {
                    try self.analyzeStmt(s);
                }
            },
        }
    }

    fn checkExpr(self: *Analyzer, expr: *const Expr) AnalyzerError!DataType {
        return switch (expr.*) {
            .integer => .INT,
            .float => .FLOAT,
            .string => .STRING,
            .boolean => .BOOL,
            .identifier => |name| blk: {
                const symbol = self.symbol_table.get(name) orelse {
                    const err = try std.fmt.allocPrint(
                        self.allocator,
                        "Undefined variable '{s}'",
                        .{name},
                    );
                    try self.errors.append(self.allocator, err);
                    return AnalyzerError.UndefinedVariable;
                };
                break :blk symbol.data_type;
            },
            .binary => |bin| blk: {
                const left_type = try self.checkExpr(&bin.left);
                const right_type = try self.checkExpr(&bin.right);

                switch (bin.operator) {
                    .ADD, .SUB, .MUL, .DIV => {
                        // Arithmetic operations
                        if (left_type == .INT and right_type == .INT) {
                            break :blk .INT;
                        } else if (left_type == .FLOAT and right_type == .FLOAT) {
                            break :blk .FLOAT;
                        } else if ((left_type == .INT or left_type == .FLOAT) and
                            (right_type == .INT or right_type == .FLOAT))
                        {
                            break :blk .FLOAT;
                        } else if (bin.operator == .ADD and left_type == .STRING and right_type == .STRING) {
                            // String concatenation
                            break :blk .STRING;
                        } else {
                            const left_type_str = try left_type.toString(self.allocator);
                            defer self.allocator.free(left_type_str);
                            const right_type_str = try right_type.toString(self.allocator);
                            defer self.allocator.free(right_type_str);
                            const err = try std.fmt.allocPrint(
                                self.allocator,
                                "Invalid operation: {s} {s} {s}",
                                .{ left_type_str, @tagName(bin.operator), right_type_str },
                            );
                            try self.errors.append(self.allocator, err);
                            return AnalyzerError.InvalidOperation;
                        }
                    },
                    .EQ, .NEQ, .LT, .GT, .LTE, .GTE => {
                        // Comparison operations
                        if (!self.typesEqual(left_type, right_type)) {
                            const left_type_str = try left_type.toString(self.allocator);
                            defer self.allocator.free(left_type_str);
                            const right_type_str = try right_type.toString(self.allocator);
                            defer self.allocator.free(right_type_str);
                            const err = try std.fmt.allocPrint(
                                self.allocator,
                                "Cannot compare {s} with {s}",
                                .{ left_type_str, right_type_str },
                            );
                            try self.errors.append(self.allocator, err);
                            return AnalyzerError.TypeMismatch;
                        }
                        break :blk .BOOL;
                    },
                }
            },
            .unary => |un| blk: {
                const operand_type = try self.checkExpr(&un.operand);
                switch (un.operator) {
                    .NEG => {
                        if (operand_type == .INT or operand_type == .FLOAT) {
                            break :blk operand_type;
                        } else {
                            return AnalyzerError.InvalidOperation;
                        }
                    },
                    .NOT => {
                        if (operand_type == .BOOL) {
                            break :blk .BOOL;
                        } else {
                            return AnalyzerError.InvalidOperation;
                        }
                    },
                }
            },
            .call => |call| blk: {
                // Look up function in function table
                const func_sig = self.function_table.get(call.name) orelse {
                    const err = try std.fmt.allocPrint(
                        self.allocator,
                        "Undefined function '{s}'",
                        .{call.name},
                    );
                    try self.errors.append(self.allocator, err);
                    return AnalyzerError.UndefinedVariable;
                };

                // Check argument count
                if (call.args.len != func_sig.param_types.len) {
                    const err = try std.fmt.allocPrint(
                        self.allocator,
                        "Function '{s}' expects {d} arguments, got {d}",
                        .{ call.name, func_sig.param_types.len, call.args.len },
                    );
                    try self.errors.append(self.allocator, err);
                    return AnalyzerError.TypeMismatch;
                }

                // Check argument types
                for (call.args, 0..) |*arg, i| {
                    const arg_type = try self.checkExpr(arg);
                    if (!self.typesEqual(arg_type, func_sig.param_types[i])) {
                        const expected_type_str = try func_sig.param_types[i].toString(self.allocator);
                        defer self.allocator.free(expected_type_str);
                        const arg_type_str = try arg_type.toString(self.allocator);
                        defer self.allocator.free(arg_type_str);
                        const err = try std.fmt.allocPrint(
                            self.allocator,
                            "Type mismatch in argument {d} of function '{s}': expected {s}, got {s}",
                            .{ i + 1, call.name, expected_type_str, arg_type_str },
                        );
                        try self.errors.append(self.allocator, err);
                        return AnalyzerError.TypeMismatch;
                    }
                }

                // Return the function's return type
                break :blk func_sig.return_type;
            },
            .array_literal => {
                // TODO: Implement in Phase 4
                return AnalyzerError.InvalidOperation;
            },
            .index_access => {
                // TODO: Implement in Phase 4
                return AnalyzerError.InvalidOperation;
            },
            .member_access => {
                // TODO: Implement in Phase 4
                return AnalyzerError.InvalidOperation;
            },
            .method_call => {
                // TODO: Implement in Phase 4
                return AnalyzerError.InvalidOperation;
            },
        };
    }
};
