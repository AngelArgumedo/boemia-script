const std = @import("std");
const testing = std.testing;
const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;
const Analyzer = @import("analyzer.zig").Analyzer;

test "analyzer: accept valid variable declaration" {
    const allocator = testing.allocator;
    const source = "let x: int = 42;";

    var lexer = Lexer.init(allocator, source);
    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    var analyzer = Analyzer.init(allocator);
    defer analyzer.deinit();

    try analyzer.analyze(&program);
    try testing.expectEqual(@as(usize, 0), analyzer.errors.items.len);
}

test "analyzer: detect type mismatch in assignment" {
    const allocator = testing.allocator;
    const source = "let x: int = \"hello\";";

    var lexer = Lexer.init(allocator, source);
    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    var analyzer = Analyzer.init(allocator);
    defer analyzer.deinit();

    const result = analyzer.analyze(&program);
    try testing.expectError(error.TypeMismatch, result);
    try testing.expect(analyzer.errors.items.len > 0);
}

test "analyzer: detect undefined variable" {
    const allocator = testing.allocator;
    const source = "x = 10;";

    var lexer = Lexer.init(allocator, source);
    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    var analyzer = Analyzer.init(allocator);
    defer analyzer.deinit();

    const result = analyzer.analyze(&program);
    try testing.expectError(error.UndefinedVariable, result);
}

test "analyzer: detect constant reassignment" {
    const allocator = testing.allocator;
    const source =
        \\const PI: float = 3.14;
        \\PI = 3.15;
    ;

    var lexer = Lexer.init(allocator, source);
    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    var analyzer = Analyzer.init(allocator);
    defer analyzer.deinit();

    const result = analyzer.analyze(&program);
    try testing.expectError(error.ConstantAssignment, result);
}

test "analyzer: accept variable reassignment" {
    const allocator = testing.allocator;
    const source =
        \\let x: int = 5;
        \\x = 10;
    ;

    var lexer = Lexer.init(allocator, source);
    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    var analyzer = Analyzer.init(allocator);
    defer analyzer.deinit();

    try analyzer.analyze(&program);
    try testing.expectEqual(@as(usize, 0), analyzer.errors.items.len);
}

test "analyzer: detect type mismatch in reassignment" {
    const allocator = testing.allocator;
    const source =
        \\let x: int = 5;
        \\x = "hello";
    ;

    var lexer = Lexer.init(allocator, source);
    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    var analyzer = Analyzer.init(allocator);
    defer analyzer.deinit();

    const result = analyzer.analyze(&program);
    try testing.expectError(error.TypeMismatch, result);
}

test "analyzer: accept arithmetic operations on same types" {
    const allocator = testing.allocator;
    const source = "let result: int = 5 + 10;";

    var lexer = Lexer.init(allocator, source);
    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    var analyzer = Analyzer.init(allocator);
    defer analyzer.deinit();

    try analyzer.analyze(&program);
    try testing.expectEqual(@as(usize, 0), analyzer.errors.items.len);
}

test "analyzer: accept comparison in if condition" {
    const allocator = testing.allocator;
    const source =
        \\let x: int = 5;
        \\if x > 3 {
        \\    let y: int = 10;
        \\}
    ;

    var lexer = Lexer.init(allocator, source);
    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    var analyzer = Analyzer.init(allocator);
    defer analyzer.deinit();

    try analyzer.analyze(&program);
    try testing.expectEqual(@as(usize, 0), analyzer.errors.items.len);
}

test "analyzer: detect redeclaration of variable" {
    const allocator = testing.allocator;
    const source =
        \\let x: int = 5;
        \\let x: int = 10;
    ;

    var lexer = Lexer.init(allocator, source);
    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    var analyzer = Analyzer.init(allocator);
    defer analyzer.deinit();

    const result = analyzer.analyze(&program);
    try testing.expectError(error.RedeclaredVariable, result);
}

test "analyzer: accept string concatenation" {
    const allocator = testing.allocator;
    const source = "let greeting: string = \"Hello\" + \" World\";";

    var lexer = Lexer.init(allocator, source);
    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    var analyzer = Analyzer.init(allocator);
    defer analyzer.deinit();

    try analyzer.analyze(&program);
    try testing.expectEqual(@as(usize, 0), analyzer.errors.items.len);
}

test "analyzer: accept boolean expressions" {
    const allocator = testing.allocator;
    const source = "let flag: bool = true;";

    var lexer = Lexer.init(allocator, source);
    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    var analyzer = Analyzer.init(allocator);
    defer analyzer.deinit();

    try analyzer.analyze(&program);
    try testing.expectEqual(@as(usize, 0), analyzer.errors.items.len);
}
