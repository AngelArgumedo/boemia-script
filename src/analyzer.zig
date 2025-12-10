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

pub const Analyzer = struct {
    allocator: std.mem.Allocator,
    symbol_table: std.StringHashMap(Symbol),
    errors: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator) Analyzer {
        return Analyzer{
            .allocator = allocator,
            .symbol_table = std.StringHashMap(Symbol).init(allocator),
            .errors = .empty,
        };
    }

    pub fn deinit(self: *Analyzer) void {
        self.symbol_table.deinit();
        for (self.errors.items) |err| {
            self.allocator.free(err);
        }
        self.errors.deinit(self.allocator);
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
                if (expr_type != decl.data_type) {
                    const err = try std.fmt.allocPrint(
                        self.allocator,
                        "Type mismatch: cannot assign {s} to {s}",
                        .{ expr_type.toString(), decl.data_type.toString() },
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
                if (expr_type != symbol.data_type) {
                    const err = try std.fmt.allocPrint(
                        self.allocator,
                        "Type mismatch: cannot assign {s} to {s}",
                        .{ expr_type.toString(), symbol.data_type.toString() },
                    );
                    try self.errors.append(self.allocator, err);
                    return AnalyzerError.TypeMismatch;
                }
            },
            .if_stmt => |if_stmt| {
                const cond_type = try self.checkExpr(&if_stmt.condition);
                if (cond_type != .BOOL) {
                    const err = try std.fmt.allocPrint(
                        self.allocator,
                        "If condition must be bool, got {s}",
                        .{cond_type.toString()},
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
                    const err = try std.fmt.allocPrint(
                        self.allocator,
                        "While condition must be bool, got {s}",
                        .{cond_type.toString()},
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
                    const err = try std.fmt.allocPrint(
                        self.allocator,
                        "For condition must be bool, got {s}",
                        .{cond_type.toString()},
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
                            const err = try std.fmt.allocPrint(
                                self.allocator,
                                "Invalid operation: {s} {s} {s}",
                                .{ left_type.toString(), @tagName(bin.operator), right_type.toString() },
                            );
                            try self.errors.append(self.allocator, err);
                            return AnalyzerError.InvalidOperation;
                        }
                    },
                    .EQ, .NEQ, .LT, .GT, .LTE, .GTE => {
                        // Comparison operations
                        if (left_type != right_type) {
                            const err = try std.fmt.allocPrint(
                                self.allocator,
                                "Cannot compare {s} with {s}",
                                .{ left_type.toString(), right_type.toString() },
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
                _ = call;
                // For now, we'll just return VOID
                // Proper function type checking would go here
                break :blk .VOID;
            },
        };
    }
};
