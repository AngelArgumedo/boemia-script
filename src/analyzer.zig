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
    struct_table: std.StringHashMap(DataType.StructType),
    errors: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator) Analyzer {
        return Analyzer{
            .allocator = allocator,
            .symbol_table = std.StringHashMap(Symbol).init(allocator),
            .function_table = std.StringHashMap(FunctionSignature).init(allocator),
            .struct_table = std.StringHashMap(DataType.StructType).init(allocator),
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

        // Free struct types
        var struct_it = self.struct_table.iterator();
        while (struct_it.next()) |entry| {
            for (entry.value_ptr.fields) |field| {
                field.field_type.deinit();
                self.allocator.destroy(field.field_type);
            }
            self.allocator.free(entry.value_ptr.fields);
        }
        self.struct_table.deinit();

        for (self.errors.items) |err| {
            self.allocator.free(err);
        }
        self.errors.deinit(self.allocator);
    }

    fn resolveStructType(self: *Analyzer, data_type: DataType) AnalyzerError!DataType {
        switch (data_type) {
            .STRUCT => |struct_type| {
                // Look up the struct in the struct_table to get full definition
                if (self.struct_table.get(struct_type.name)) |full_struct| {
                    const resolved_ptr = try self.allocator.create(DataType.StructType);
                    resolved_ptr.* = full_struct;
                    return DataType{ .STRUCT = resolved_ptr };
                } else {
                    return data_type; // Return as-is if not found (will be caught by validation)
                }
            },
            else => return data_type,
        }
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
            .STRUCT => |struct_a| {
                switch (b) {
                    .STRUCT => |struct_b| {
                        // Los structs son iguales si tienen el mismo nombre
                        return std.mem.eql(u8, struct_a.name, struct_b.name);
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

                // Resolve struct types to get full definition
                const resolved_type = try self.resolveStructType(decl.data_type);

                // Check type compatibility
                if (!self.typesEqual(expr_type, resolved_type)) {
                    const expr_type_str = try expr_type.toString(self.allocator);
                    const decl_type_str = try resolved_type.toString(self.allocator);
                    const err = try std.fmt.allocPrint(
                        self.allocator,
                        "Type mismatch: cannot assign {s} to {s}",
                        .{ expr_type_str, decl_type_str },
                    );
                    try self.errors.append(self.allocator, err);
                    return AnalyzerError.TypeMismatch;
                }

                try self.symbol_table.put(decl.name, Symbol{
                    .data_type = resolved_type,
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
                    const symbol_type_str = try symbol.data_type.toString(self.allocator);
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
            .for_in_stmt => |for_in| {
                // Get type of iterable
                const iterable_type = try self.checkExpr(&for_in.iterable);

                // Iterable must be an array
                switch (iterable_type) {
                    .ARRAY => |arr_type| {
                        // Register iterator variable with element type
                        const elem_type = arr_type.element_type.*;

                        // Store the iterator type in the AST for codegen
                        for_in.iterator_type = elem_type;

                        try self.symbol_table.put(for_in.iterator, Symbol{
                            .data_type = elem_type,
                            .is_const = true, // Iterator is read-only
                        });

                        // Analyze body
                        for (for_in.body) |*s| {
                            try self.analyzeStmt(s);
                        }

                        // Remove iterator from symbol table
                        _ = self.symbol_table.remove(for_in.iterator);
                    },
                    else => {
                        const iter_type_str = try iterable_type.toString(self.allocator);
                        const err = try std.fmt.allocPrint(
                            self.allocator,
                            "For-in iterable must be an array, got {s}",
                            .{iter_type_str},
                        );
                        try self.errors.append(self.allocator, err);
                        return AnalyzerError.TypeMismatch;
                    },
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
            .struct_decl => |struct_decl| {
                // Check if struct already exists
                if (self.struct_table.get(struct_decl.name)) |_| {
                    const err = try std.fmt.allocPrint(
                        self.allocator,
                        "Struct '{s}' is already declared",
                        .{struct_decl.name},
                    );
                    try self.errors.append(self.allocator, err);
                    return AnalyzerError.RedeclaredVariable;
                }

                // Validate that all field types exist
                for (struct_decl.fields) |field| {
                    // Check if field type is a struct that exists
                    switch (field.field_type.*) {
                        .STRUCT => |field_struct| {
                            if (self.struct_table.get(field_struct.name) == null) {
                                const err = try std.fmt.allocPrint(
                                    self.allocator,
                                    "Undefined struct type '{s}' in field '{s}'",
                                    .{ field_struct.name, field.name },
                                );
                                try self.errors.append(self.allocator, err);
                                return AnalyzerError.TypeMismatch;
                            }
                        },
                        else => {},
                    }
                }

                // Check for duplicate field names
                for (struct_decl.fields, 0..) |field, i| {
                    for (struct_decl.fields[i + 1 ..]) |other_field| {
                        if (std.mem.eql(u8, field.name, other_field.name)) {
                            const err = try std.fmt.allocPrint(
                                self.allocator,
                                "Duplicate field '{s}' in struct '{s}'",
                                .{ field.name, struct_decl.name },
                            );
                            try self.errors.append(self.allocator, err);
                            return AnalyzerError.RedeclaredVariable;
                        }
                    }
                }

                // Resolve struct field types before registering
                for (struct_decl.fields) |field| {
                    const resolved_type = try self.resolveStructType(field.field_type.*);
                    field.field_type.* = resolved_type;
                }

                // Register struct in struct table
                try self.struct_table.put(struct_decl.name, DataType.StructType{
                    .name = struct_decl.name,
                    .fields = struct_decl.fields,
                    .allocator = self.allocator,
                });
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
                            const right_type_str = try right_type.toString(self.allocator);
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
                            const right_type_str = try right_type.toString(self.allocator);
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
                        const arg_type_str = try arg_type.toString(self.allocator);
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
            .array_literal => |arr| blk: {
                // Array vacio necesita anotacion de tipo explícita
                if (arr.elements.len == 0) {
                    const err = try std.fmt.allocPrint(
                        self.allocator,
                        "Empty array literals require type annotation",
                        .{},
                    );
                    try self.errors.append(self.allocator, err);
                    return AnalyzerError.TypeMismatch;
                }

                // Inferir tipo del primer elemento
                const first_type = try self.checkExpr(&arr.elements[0]);

                // Verificar que todos los elementos sean del mismo tipo
                for (arr.elements[1..]) |*elem| {
                    const elem_type = try self.checkExpr(elem);
                    if (!self.typesEqual(elem_type, first_type)) {
                        // Note: We don't free these strings because simple types return string literals
                        // Only ARRAY types allocate memory, but those will be freed when Program.deinit() is called
                        const first_type_str = try first_type.toString(self.allocator);
                        const elem_type_str = try elem_type.toString(self.allocator);
                        const err = try std.fmt.allocPrint(
                            self.allocator,
                            "Array elements must have the same type: expected {s}, got {s}",
                            .{ first_type_str, elem_type_str },
                        );
                        try self.errors.append(self.allocator, err);
                        return AnalyzerError.TypeMismatch;
                    }
                }

                // Crear tipo [T]
                const elem_type_ptr = try self.allocator.create(DataType);
                elem_type_ptr.* = first_type;

                const array_type = try self.allocator.create(DataType.ArrayType);
                array_type.* = .{
                    .element_type = elem_type_ptr,
                    .allocator = self.allocator,
                };

                const result_type = DataType{ .ARRAY = array_type };

                break :blk result_type;
            },
            .index_access => |idx| blk: {
                const array_type = try self.checkExpr(&idx.array);
                const index_type = try self.checkExpr(&idx.index);

                // El índice debe ser int
                if (index_type != .INT) {
                    const index_type_str = try index_type.toString(self.allocator);
                    const err = try std.fmt.allocPrint(
                        self.allocator,
                        "Array index must be int, got {s}",
                        .{index_type_str},
                    );
                    try self.errors.append(self.allocator, err);
                    return AnalyzerError.TypeMismatch;
                }

                // array_type debe ser ARRAY
                switch (array_type) {
                    .ARRAY => |arr_type| break :blk arr_type.element_type.*,
                    else => {
                        const arr_type_str = try array_type.toString(self.allocator);
                        const err = try std.fmt.allocPrint(
                            self.allocator,
                            "Cannot index into non-array type {s}",
                            .{arr_type_str},
                        );
                        try self.errors.append(self.allocator, err);
                        return AnalyzerError.TypeMismatch;
                    },
                }
            },
            .member_access => |mem| blk: {
                const object_type = try self.checkExpr(&mem.object);

                switch (object_type) {
                    .ARRAY => {
                        // Solo soportamos .length por ahora
                        if (std.mem.eql(u8, mem.member, "length")) {
                            break :blk DataType.INT;
                        } else {
                            const err = try std.fmt.allocPrint(
                                self.allocator,
                                "Unknown array property '{s}' (only 'length' is supported)",
                                .{mem.member},
                            );
                            try self.errors.append(self.allocator, err);
                            return AnalyzerError.InvalidOperation;
                        }
                    },
                    .STRUCT => |struct_type| {
                        // Buscar el campo en el struct
                        for (struct_type.fields) |field| {
                            if (std.mem.eql(u8, field.name, mem.member)) {
                                // Retornar el tipo del campo
                                break :blk field.field_type.*;
                            }
                        }
                        // Campo no encontrado
                        const err = try std.fmt.allocPrint(
                            self.allocator,
                            "Struct '{s}' does not have field '{s}'",
                            .{ struct_type.name, mem.member },
                        );
                        try self.errors.append(self.allocator, err);
                        return AnalyzerError.InvalidOperation;
                    },
                    else => {
                        const obj_type_str = try object_type.toString(self.allocator);
                        const err = try std.fmt.allocPrint(
                            self.allocator,
                            "Type {s} does not have property '{s}'",
                            .{ obj_type_str, mem.member },
                        );
                        try self.errors.append(self.allocator, err);
                        return AnalyzerError.InvalidOperation;
                    },
                }
            },
            .method_call => |meth| blk: {
                const object_type = try self.checkExpr(&meth.object);

                switch (object_type) {
                    .ARRAY => |arr_type| {
                        // Solo soportamos .push() por ahora
                        if (std.mem.eql(u8, meth.method, "push")) {
                            // Verificar 1 argumento
                            if (meth.args.len != 1) {
                                const err = try std.fmt.allocPrint(
                                    self.allocator,
                                    "Method 'push' expects 1 argument, got {d}",
                                    .{meth.args.len},
                                );
                                try self.errors.append(self.allocator, err);
                                return AnalyzerError.TypeMismatch;
                            }

                            // Verificar tipo del argumento
                            const arg_type = try self.checkExpr(&meth.args[0]);
                            if (!self.typesEqual(arg_type, arr_type.element_type.*)) {
                                const expected_type_str = try arr_type.element_type.toString(self.allocator);
                                const arg_type_str = try arg_type.toString(self.allocator);
                                const err = try std.fmt.allocPrint(
                                    self.allocator,
                                    "Method 'push' expects argument of type {s}, got {s}",
                                    .{ expected_type_str, arg_type_str },
                                );
                                try self.errors.append(self.allocator, err);
                                return AnalyzerError.TypeMismatch;
                            }

                            break :blk DataType.VOID;
                        } else {
                            const err = try std.fmt.allocPrint(
                                self.allocator,
                                "Unknown array method '{s}' (only 'push' is supported)",
                                .{meth.method},
                            );
                            try self.errors.append(self.allocator, err);
                            return AnalyzerError.InvalidOperation;
                        }
                    },
                    else => {
                        const obj_type_str = try object_type.toString(self.allocator);
                        const err = try std.fmt.allocPrint(
                            self.allocator,
                            "Type {s} does not have method '{s}'",
                            .{ obj_type_str, meth.method },
                        );
                        try self.errors.append(self.allocator, err);
                        return AnalyzerError.InvalidOperation;
                    },
                }
            },
            .struct_literal => |struct_lit| blk: {
                // Verificar que el struct exista
                const struct_type = self.struct_table.get(struct_lit.struct_name) orelse {
                    const err = try std.fmt.allocPrint(
                        self.allocator,
                        "Undefined struct type '{s}'",
                        .{struct_lit.struct_name},
                    );
                    try self.errors.append(self.allocator, err);
                    return AnalyzerError.UndefinedVariable;
                };

                // Verificar que todos los campos requeridos esten presentes
                for (struct_type.fields) |field| {
                    var found = false;
                    for (struct_lit.field_values) |field_val| {
                        if (std.mem.eql(u8, field.name, field_val.field_name)) {
                            found = true;
                            break;
                        }
                    }
                    if (!found) {
                        const err = try std.fmt.allocPrint(
                            self.allocator,
                            "Missing field '{s}' in struct literal '{s}'",
                            .{ field.name, struct_lit.struct_name },
                        );
                        try self.errors.append(self.allocator, err);
                        return AnalyzerError.TypeMismatch;
                    }
                }

                // Verificar que no haya campos extra
                for (struct_lit.field_values) |field_val| {
                    var found = false;
                    for (struct_type.fields) |field| {
                        if (std.mem.eql(u8, field.name, field_val.field_name)) {
                            found = true;
                            break;
                        }
                    }
                    if (!found) {
                        const err = try std.fmt.allocPrint(
                            self.allocator,
                            "Unknown field '{s}' in struct '{s}'",
                            .{ field_val.field_name, struct_lit.struct_name },
                        );
                        try self.errors.append(self.allocator, err);
                        return AnalyzerError.TypeMismatch;
                    }
                }

                // Verificar que los tipos de los valores coincidan
                for (struct_lit.field_values) |field_val| {
                    const value_type = try self.checkExpr(&field_val.value);

                    // Buscar el tipo esperado del campo
                    var expected_type: ?DataType = null;
                    for (struct_type.fields) |field| {
                        if (std.mem.eql(u8, field.name, field_val.field_name)) {
                            expected_type = field.field_type.*;
                            break;
                        }
                    }

                    if (expected_type) |exp_type| {
                        if (!self.typesEqual(value_type, exp_type)) {
                            const value_type_str = try value_type.toString(self.allocator);
                            const exp_type_str = try exp_type.toString(self.allocator);
                            const err = try std.fmt.allocPrint(
                                self.allocator,
                                "Type mismatch for field '{s}': expected {s}, got {s}",
                                .{ field_val.field_name, exp_type_str, value_type_str },
                            );
                            try self.errors.append(self.allocator, err);
                            return AnalyzerError.TypeMismatch;
                        }
                    }
                }

                // Retornar tipo struct
                const struct_type_ptr = try self.allocator.create(DataType.StructType);
                struct_type_ptr.* = struct_type;

                break :blk DataType{ .STRUCT = struct_type_ptr };
            },
        };
    }
};
