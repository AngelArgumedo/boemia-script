const std = @import("std");
const testing = std.testing;
const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;
const Analyzer = @import("analyzer.zig").Analyzer;
const codegen = @import("codegen.zig");

fn compileAndCheckOutput(allocator: std.mem.Allocator, source: []const u8) ![]const u8 {
    var lexer = Lexer.init(allocator, source);
    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    var analyzer = try Analyzer.init(allocator);
    defer analyzer.deinit();

    try analyzer.analyze(&program);

    var code_generator = try codegen.CodeGenerator.init(allocator);
    defer code_generator.deinit();

    const c_code = try code_generator.generate(&program);
    // Make a copy since c_code will be freed when code_generator.deinit() is called
    const c_code_copy = try allocator.dupe(u8, c_code);
    return c_code_copy;
}

test "integration: compile simple integer variable" {
    const allocator = testing.allocator;
    const source = "let x: int = 42;";

    const c_code = try compileAndCheckOutput(allocator, source);
    defer allocator.free(c_code);

    try testing.expect(std.mem.indexOf(u8, c_code, "long long x = 42;") != null);
}

test "integration: compile string variable" {
    const allocator = testing.allocator;
    const source = "let msg: string = \"Hello\";";

    const c_code = try compileAndCheckOutput(allocator, source);
    defer allocator.free(c_code);

    try testing.expect(std.mem.indexOf(u8, c_code, "char* msg = \"Hello\";") != null);
}

test "integration: compile constant with seal" {
    const allocator = testing.allocator;
    const source = "const PI: float = 3.14;";

    const c_code = try compileAndCheckOutput(allocator, source);
    defer allocator.free(c_code);

    try testing.expect(std.mem.indexOf(u8, c_code, "const double PI = 3.14") != null);
}

test "integration: compile print statement with integer" {
    const allocator = testing.allocator;
    const source =
        \\let x: int = 42;
        \\print(x);
    ;

    const c_code = try compileAndCheckOutput(allocator, source);
    defer allocator.free(c_code);

    try testing.expect(std.mem.indexOf(u8, c_code, "printf(\"%lld\\n\", (long long)x);") != null);
}

test "integration: compile print statement with string" {
    const allocator = testing.allocator;
    const source =
        \\let msg: string = "Hello";
        \\print(msg);
    ;

    const c_code = try compileAndCheckOutput(allocator, source);
    defer allocator.free(c_code);

    try testing.expect(std.mem.indexOf(u8, c_code, "printf(\"%s\\n\", msg);") != null);
}

test "integration: compile if statement" {
    const allocator = testing.allocator;
    const source =
        \\let x: int = 10;
        \\if x > 5 {
        \\    let y: int = 20;
        \\}
    ;

    const c_code = try compileAndCheckOutput(allocator, source);
    defer allocator.free(c_code);

    try testing.expect(std.mem.indexOf(u8, c_code, "if ((x > 5))") != null);
    try testing.expect(std.mem.indexOf(u8, c_code, "long long y = 20;") != null);
}

test "integration: compile if-else statement" {
    const allocator = testing.allocator;
    const source =
        \\let x: int = 3;
        \\if x > 5 {
        \\    let y: int = 20;
        \\} else {
        \\    let y: int = 10;
        \\}
    ;

    const c_code = try compileAndCheckOutput(allocator, source);
    defer allocator.free(c_code);

    try testing.expect(std.mem.indexOf(u8, c_code, "} else {") != null);
}

test "integration: compile while loop" {
    const allocator = testing.allocator;
    const source =
        \\let x: int = 0;
        \\while x < 5 {
        \\    x = x + 1;
        \\}
    ;

    const c_code = try compileAndCheckOutput(allocator, source);
    defer allocator.free(c_code);

    try testing.expect(std.mem.indexOf(u8, c_code, "while ((x < 5))") != null);
    try testing.expect(std.mem.indexOf(u8, c_code, "x = (x + 1);") != null);
}

test "integration: compile for loop" {
    const allocator = testing.allocator;
    const source =
        \\for i: int = 0; i < 10; i = i + 1 {
        \\    print(i);
        \\}
    ;

    const c_code = try compileAndCheckOutput(allocator, source);
    defer allocator.free(c_code);

    try testing.expect(std.mem.indexOf(u8, c_code, "for (long long i = 0;") != null);
    try testing.expect(std.mem.indexOf(u8, c_code, "i < 10;") != null);
    try testing.expect(std.mem.indexOf(u8, c_code, "i = (i + 1))") != null);
}

test "integration: compile arithmetic expressions" {
    const allocator = testing.allocator;
    const source = "let result: int = 5 + 3 * 2;";

    const c_code = try compileAndCheckOutput(allocator, source);
    defer allocator.free(c_code);

    try testing.expect(std.mem.indexOf(u8, c_code, "long long result =") != null);
}

test "integration: compile boolean variable" {
    const allocator = testing.allocator;
    const source = "let flag: bool = true;";

    const c_code = try compileAndCheckOutput(allocator, source);
    defer allocator.free(c_code);

    try testing.expect(std.mem.indexOf(u8, c_code, "bool flag = true;") != null);
}

test "integration: compile comparison expression" {
    const allocator = testing.allocator;
    const source =
        \\let x: int = 5;
        \\let result: bool = x == 5;
    ;

    const c_code = try compileAndCheckOutput(allocator, source);
    defer allocator.free(c_code);

    try testing.expect(std.mem.indexOf(u8, c_code, "(x == 5)") != null);
}

test "integration: full program with multiple features" {
    const allocator = testing.allocator;
    const source =
        \\let x: int = 10;
        \\let y: int = 20;
        \\let sum: int = x + y;
        \\
        \\if sum > 25 {
        \\    print(sum);
        \\} else {
        \\    print(x);
        \\}
    ;

    const c_code = try compileAndCheckOutput(allocator, source);
    defer allocator.free(c_code);

    // Verify variables are declared
    try testing.expect(std.mem.indexOf(u8, c_code, "long long x = 10;") != null);
    try testing.expect(std.mem.indexOf(u8, c_code, "long long y = 20;") != null);
    try testing.expect(std.mem.indexOf(u8, c_code, "long long sum = (x + y);") != null);

    // Verify if-else structure
    try testing.expect(std.mem.indexOf(u8, c_code, "if ((sum > 25))") != null);
    try testing.expect(std.mem.indexOf(u8, c_code, "} else {") != null);
}
