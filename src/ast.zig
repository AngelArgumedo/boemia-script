const std = @import("std");

/// Data types in Boemia Script
pub const DataType = enum {
    INT,
    FLOAT,
    STRING,
    BOOL,
    VOID,

    pub fn fromString(s: []const u8) ?DataType {
        if (std.mem.eql(u8, s, "int")) return .INT;
        if (std.mem.eql(u8, s, "float")) return .FLOAT;
        if (std.mem.eql(u8, s, "string")) return .STRING;
        if (std.mem.eql(u8, s, "bool")) return .BOOL;
        return null;
    }

    pub fn toString(self: DataType) []const u8 {
        return switch (self) {
            .INT => "int",
            .FLOAT => "float",
            .STRING => "string",
            .BOOL => "bool",
            .VOID => "void",
        };
    }
};

/// Expression types
pub const Expr = union(enum) {
    integer: i64,
    float: f64,
    string: []const u8,
    boolean: bool,
    identifier: []const u8,
    binary: *BinaryExpr,
    unary: *UnaryExpr,
    call: *CallExpr,

    pub const BinaryExpr = struct {
        left: Expr,
        operator: BinaryOp,
        right: Expr,
    };

    pub const UnaryExpr = struct {
        operator: UnaryOp,
        operand: Expr,
    };

    pub const CallExpr = struct {
        name: []const u8,
        args: []Expr,
    };

    pub fn deinit(self: *Expr, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .binary => |bin| {
                bin.left.deinit(allocator);
                bin.right.deinit(allocator);
                allocator.destroy(bin);
            },
            .unary => |un| {
                un.operand.deinit(allocator);
                allocator.destroy(un);
            },
            .call => |call| {
                for (call.args) |*arg| {
                    arg.deinit(allocator);
                }
                allocator.free(call.args);
                allocator.destroy(call);
            },
            else => {},
        }
    }
};

/// Binary operators
pub const BinaryOp = enum {
    ADD,
    SUB,
    MUL,
    DIV,
    EQ,
    NEQ,
    LT,
    GT,
    LTE,
    GTE,
};

/// Unary operators
pub const UnaryOp = enum {
    NEG,
    NOT,
};

/// Statement types
pub const Stmt = union(enum) {
    variable_decl: VariableDecl,
    assignment: Assignment,
    if_stmt: *IfStmt,
    while_stmt: *WhileStmt,
    for_stmt: *ForStmt,
    return_stmt: *ReturnStmt,
    expr_stmt: Expr,
    print_stmt: Expr,
    block: []Stmt,
    function_decl: *FunctionDecl,

    pub const VariableDecl = struct {
        name: []const u8,
        data_type: DataType,
        value: Expr,
        is_const: bool,
    };

    pub const Assignment = struct {
        name: []const u8,
        value: Expr,
    };

    pub const IfStmt = struct {
        condition: Expr,
        then_block: []Stmt,
        else_block: ?[]Stmt,
    };

    pub const WhileStmt = struct {
        condition: Expr,
        body: []Stmt,
    };

    pub const ForStmt = struct {
        init: ?*Stmt,
        condition: Expr,
        update: ?*Stmt,
        body: []Stmt,
    };

    pub const ReturnStmt = struct {
        value: ?Expr,
    };

    pub const FunctionDecl = struct {
        name: []const u8,
        params: []Parameter,
        return_type: DataType,
        body: []Stmt,
    };

    pub const Parameter = struct {
        name: []const u8,
        data_type: DataType,
    };

    pub fn deinit(self: *Stmt, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .variable_decl => |*decl| {
                decl.value.deinit(allocator);
            },
            .assignment => |*assign| {
                assign.value.deinit(allocator);
            },
            .if_stmt => |if_s| {
                if_s.condition.deinit(allocator);
                for (if_s.then_block) |*stmt| {
                    stmt.deinit(allocator);
                }
                allocator.free(if_s.then_block);
                if (if_s.else_block) |else_block| {
                    for (else_block) |*stmt| {
                        stmt.deinit(allocator);
                    }
                    allocator.free(else_block);
                }
                allocator.destroy(if_s);
            },
            .while_stmt => |while_s| {
                while_s.condition.deinit(allocator);
                for (while_s.body) |*stmt| {
                    stmt.deinit(allocator);
                }
                allocator.free(while_s.body);
                allocator.destroy(while_s);
            },
            .for_stmt => |for_s| {
                if (for_s.init) |init| {
                    init.deinit(allocator);
                    allocator.destroy(init);
                }
                for_s.condition.deinit(allocator);
                if (for_s.update) |update| {
                    update.deinit(allocator);
                    allocator.destroy(update);
                }
                for (for_s.body) |*stmt| {
                    stmt.deinit(allocator);
                }
                allocator.free(for_s.body);
                allocator.destroy(for_s);
            },
            .return_stmt => |ret| {
                if (ret.value) |*val| {
                    val.deinit(allocator);
                }
                allocator.destroy(ret);
            },
            .expr_stmt => |*expr| {
                expr.deinit(allocator);
            },
            .print_stmt => |*expr| {
                expr.deinit(allocator);
            },
            .block => |stmts| {
                for (stmts) |*stmt| {
                    stmt.deinit(allocator);
                }
                allocator.free(stmts);
            },
            .function_decl => |func| {
                allocator.free(func.params);
                for (func.body) |*stmt| {
                    stmt.deinit(allocator);
                }
                allocator.free(func.body);
                allocator.destroy(func);
            },
        }
    }
};

/// Program is a collection of statements
pub const Program = struct {
    statements: []Stmt,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, statements: []Stmt) Program {
        return Program{
            .statements = statements,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Program) void {
        for (self.statements) |*stmt| {
            stmt.deinit(self.allocator);
        }
        self.allocator.free(self.statements);
    }
};
