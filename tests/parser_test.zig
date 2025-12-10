const std = @import("std");
const testing = std.testing;
const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;
const ast = @import("ast.zig");

test "parser: parse variable declaration" {
    const allocator = testing.allocator;
    const source = "make x: int = 42;";

    var lexer = Lexer.init(allocator, source);
    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    try testing.expectEqual(@as(usize, 1), program.statements.len);

    const stmt = program.statements[0];
    try testing.expect(stmt == .variable_decl);

    const decl = stmt.variable_decl;
    try testing.expectEqualStrings("x", decl.name);
    try testing.expectEqual(ast.DataType.INT, decl.data_type);
    try testing.expectEqual(false, decl.is_const);
    try testing.expect(decl.value == .integer);
    try testing.expectEqual(@as(i64, 42), decl.value.integer);
}

test "parser: parse constant declaration" {
    const allocator = testing.allocator;
    const source = "seal PI: float = 3.14;";

    var lexer = Lexer.init(allocator, source);
    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    const stmt = program.statements[0];
    const decl = stmt.variable_decl;

    try testing.expectEqual(true, decl.is_const);
    try testing.expectEqual(ast.DataType.FLOAT, decl.data_type);
}

test "parser: parse string literal" {
    const allocator = testing.allocator;
    const source = "make msg: string = \"Hello\";";

    var lexer = Lexer.init(allocator, source);
    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    const stmt = program.statements[0];
    const decl = stmt.variable_decl;

    try testing.expectEqual(ast.DataType.STRING, decl.data_type);
    try testing.expect(decl.value == .string);
    try testing.expectEqualStrings("Hello", decl.value.string);
}

test "parser: parse binary expression" {
    const allocator = testing.allocator;
    const source = "make result: int = 5 + 3;";

    var lexer = Lexer.init(allocator, source);
    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    const stmt = program.statements[0];
    const decl = stmt.variable_decl;

    try testing.expect(decl.value == .binary);
    const bin_expr = decl.value.binary;
    try testing.expectEqual(ast.BinaryOp.ADD, bin_expr.operator);
    try testing.expectEqual(@as(i64, 5), bin_expr.left.integer);
    try testing.expectEqual(@as(i64, 3), bin_expr.right.integer);
}

test "parser: parse if statement" {
    const allocator = testing.allocator;
    const source =
        \\if x > 5 {
        \\    make y: int = 10;
        \\}
    ;

    var lexer = Lexer.init(allocator, source);
    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    try testing.expectEqual(@as(usize, 1), program.statements.len);
    const stmt = program.statements[0];
    try testing.expect(stmt == .if_stmt);

    const if_stmt = stmt.if_stmt;
    try testing.expect(if_stmt.condition == .binary);
    try testing.expectEqual(@as(usize, 1), if_stmt.then_block.len);
    try testing.expect(if_stmt.else_block == null);
}

test "parser: parse if-else statement" {
    const allocator = testing.allocator;
    const source =
        \\if x > 5 {
        \\    make y: int = 10;
        \\} else {
        \\    make y: int = 20;
        \\}
    ;

    var lexer = Lexer.init(allocator, source);
    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    const stmt = program.statements[0];
    const if_stmt = stmt.if_stmt;

    try testing.expect(if_stmt.else_block != null);
    try testing.expectEqual(@as(usize, 1), if_stmt.else_block.?.len);
}

test "parser: parse while loop" {
    const allocator = testing.allocator;
    const source =
        \\while x < 10 {
        \\    x = x + 1;
        \\}
    ;

    var lexer = Lexer.init(allocator, source);
    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    const stmt = program.statements[0];
    try testing.expect(stmt == .while_stmt);

    const while_stmt = stmt.while_stmt;
    try testing.expect(while_stmt.condition == .binary);
    try testing.expectEqual(@as(usize, 1), while_stmt.body.len);
}

test "parser: parse print statement" {
    const allocator = testing.allocator;
    const source = "print(42);";

    var lexer = Lexer.init(allocator, source);
    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    const stmt = program.statements[0];
    try testing.expect(stmt == .print_stmt);
    try testing.expect(stmt.print_stmt == .integer);
}

test "parser: parse assignment" {
    const allocator = testing.allocator;
    const source = "x = 10;";

    var lexer = Lexer.init(allocator, source);
    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    const stmt = program.statements[0];
    try testing.expect(stmt == .assignment);

    const assign = stmt.assignment;
    try testing.expectEqualStrings("x", assign.name);
    try testing.expectEqual(@as(i64, 10), assign.value.integer);
}

test "parser: parse multiple statements" {
    const allocator = testing.allocator;
    const source =
        \\make x: int = 5;
        \\make y: int = 10;
        \\make sum: int = x + y;
    ;

    var lexer = Lexer.init(allocator, source);
    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    try testing.expectEqual(@as(usize, 3), program.statements.len);
}

test "parser: parse comparison operators" {
    const allocator = testing.allocator;
    const operators = [_]struct { src: []const u8, op: ast.BinaryOp }{
        .{ .src = "make a: bool = x == y;", .op = .EQ },
        .{ .src = "make b: bool = x != y;", .op = .NEQ },
        .{ .src = "make c: bool = x < y;", .op = .LT },
        .{ .src = "make d: bool = x > y;", .op = .GT },
        .{ .src = "make e: bool = x <= y;", .op = .LTE },
        .{ .src = "make f: bool = x >= y;", .op = .GTE },
    };

    for (operators) |test_case| {
        var lexer = Lexer.init(allocator, test_case.src);
        var parser = try Parser.init(allocator, &lexer);
        defer parser.deinit();

        var program = try parser.parseProgram();
        defer program.deinit();

        const stmt = program.statements[0];
        const decl = stmt.variable_decl;
        try testing.expect(decl.value == .binary);
        try testing.expectEqual(test_case.op, decl.value.binary.operator);
    }
}
