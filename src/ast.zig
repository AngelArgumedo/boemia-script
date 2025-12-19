const std = @import("std");

/// Data types in Boemia Script
pub const DataType = union(enum) {
    INT,
    FLOAT,
    STRING,
    BOOL,
    VOID,
    ARRAY: *ArrayType,

    pub const ArrayType = struct {
        element_type: *DataType,
        allocator: std.mem.Allocator,
    };

    /// Parse a type string and create DataType
    /// Supports simple types (int, float, etc.) and array syntax [T]
    pub fn fromString(allocator: std.mem.Allocator, s: []const u8) !?DataType {
        // Check for simple types first
        if (std.mem.eql(u8, s, "int")) return .INT;
        if (std.mem.eql(u8, s, "float")) return .FLOAT;
        if (std.mem.eql(u8, s, "string")) return .STRING;
        if (std.mem.eql(u8, s, "bool")) return .BOOL;
        if (std.mem.eql(u8, s, "void")) return .VOID;

        // Check for array syntax: [T]
        if (s.len >= 3 and s[0] == '[' and s[s.len - 1] == ']') {
            const inner = s[1 .. s.len - 1];
            const inner_type = try fromString(allocator, inner) orelse return null;

            const elem_type = try allocator.create(DataType);
            elem_type.* = inner_type;

            const array_type = try allocator.create(ArrayType);
            array_type.* = .{
                .element_type = elem_type,
                .allocator = allocator,
            };

            return DataType{ .ARRAY = array_type };
        }

        return null;
    }

    /// Convert DataType to string representation
    pub fn toString(self: DataType, allocator: std.mem.Allocator) ![]const u8 {
        return switch (self) {
            .INT => "int",
            .FLOAT => "float",
            .STRING => "string",
            .BOOL => "bool",
            .VOID => "void",
            .ARRAY => |arr_type| blk: {
                const inner = try arr_type.element_type.toString(allocator);
                defer allocator.free(inner);
                break :blk try std.fmt.allocPrint(allocator, "[{s}]", .{inner});
            },
        };
    }

    /// Get C-compatible name for this type (e.g., Array_int, Array_Array_int)
    pub fn toCName(self: DataType, allocator: std.mem.Allocator) ![]const u8 {
        return switch (self) {
            .INT => try allocator.dupe(u8, "int"),
            .FLOAT => try allocator.dupe(u8, "float"),
            .STRING => try allocator.dupe(u8, "string"),
            .BOOL => try allocator.dupe(u8, "bool"),
            .VOID => try allocator.dupe(u8, "void"),
            .ARRAY => |arr_type| blk: {
                const inner = try arr_type.element_type.toCName(allocator);
                defer allocator.free(inner);
                break :blk try std.fmt.allocPrint(allocator, "Array_{s}", .{inner});
            },
        };
    }

    /// Free memory for array types (recursive)
    pub fn deinit(self: *DataType) void {
        switch (self.*) {
            .ARRAY => |arr_type| {
                arr_type.element_type.deinit();
                arr_type.allocator.destroy(arr_type.element_type);
                arr_type.allocator.destroy(arr_type);
            },
            else => {},
        }
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
    array_literal: *ArrayLiteral,
    index_access: *IndexAccess,
    member_access: *MemberAccess,
    method_call: *MethodCall,

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

    pub const ArrayLiteral = struct {
        elements: []Expr,
        element_type: ?DataType,
    };

    pub const IndexAccess = struct {
        array: Expr,
        index: Expr,
    };

    pub const MemberAccess = struct {
        object: Expr,
        member: []const u8,
    };

    pub const MethodCall = struct {
        object: Expr,
        method: []const u8,
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
            .array_literal => |arr| {
                // Free optional element type
                if (arr.element_type) |elem_type| {
                    var mutable_elem_type = elem_type;
                    mutable_elem_type.deinit();
                }
                for (arr.elements) |*elem| {
                    elem.deinit(allocator);
                }
                allocator.free(arr.elements);
                allocator.destroy(arr);
            },
            .index_access => |idx| {
                idx.array.deinit(allocator);
                idx.index.deinit(allocator);
                allocator.destroy(idx);
            },
            .member_access => |mem| {
                mem.object.deinit(allocator);
                allocator.destroy(mem);
            },
            .method_call => |meth| {
                meth.object.deinit(allocator);
                for (meth.args) |*arg| {
                    arg.deinit(allocator);
                }
                allocator.free(meth.args);
                allocator.destroy(meth);
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
    for_in_stmt: *ForInStmt,
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

    pub const ForInStmt = struct {
        iterator: []const u8,
        iterator_type: ?DataType,
        iterable: Expr,
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
                var mutable_type = decl.data_type;
                mutable_type.deinit();
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
            .for_in_stmt => |for_in| {
                // DON'T free iterator_type - it's a shallow copy that shares pointers
                // with the parent array type, which will free it when the array is freed
                for_in.iterable.deinit(allocator);
                for (for_in.body) |*stmt| {
                    stmt.deinit(allocator);
                }
                allocator.free(for_in.body);
                allocator.destroy(for_in);
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
                // Free parameter data types
                for (func.params) |*param| {
                    var mutable_param_type = param.data_type;
                    mutable_param_type.deinit();
                }
                allocator.free(func.params);
                // Free return type
                var mutable_return_type = func.return_type;
                mutable_return_type.deinit();
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
