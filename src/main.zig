const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;
const Analyzer = @import("analyzer.zig").Analyzer;
const codegen = @import("codegen.zig");

pub fn main() !void {
    // Setup allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printUsage();
        return;
    }

    const input_file = args[1];
    var output_file: []const u8 = "output";

    // Check for -o flag
    var i: usize = 2;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "-o") and i + 1 < args.len) {
            output_file = args[i + 1];
            i += 1;
        }
    }

    // Read source file
    const source_code = std.fs.cwd().readFileAlloc(
        allocator,
        input_file,
        1024 * 1024, // 1MB max file size
    ) catch |err| {
        std.debug.print("Error reading file '{s}': {}\n", .{ input_file, err });
        return err;
    };
    defer allocator.free(source_code);

    std.debug.print("🚀 Boemia Script Compiler\n", .{});
    std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("📄 Input:  {s}\n", .{input_file});
    std.debug.print("📦 Output: {s}\n", .{output_file});
    std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});

    // Phase 1: Lexical Analysis
    std.debug.print("🔍 Phase 1: Lexical Analysis (Tokenization)\n", .{});
    var lexer = Lexer.init(allocator, source_code);

    // Phase 2: Syntax Analysis (Parsing)
    std.debug.print("🌳 Phase 2: Syntax Analysis (Building AST)\n", .{});
    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = parser.parseProgram() catch |err| {
        std.debug.print("\n❌ Parsing Error:\n", .{});
        for (parser.errors.items) |error_msg| {
            std.debug.print("  • {s}\n", .{error_msg});
        }
        return err;
    };
    defer program.deinit();

    if (parser.errors.items.len > 0) {
        std.debug.print("\n⚠️  Parsing Warnings:\n", .{});
        for (parser.errors.items) |warning| {
            std.debug.print("  • {s}\n", .{warning});
        }
    }

    std.debug.print("   ✓ Successfully parsed {d} statements\n", .{program.statements.len});

    // Phase 3: Semantic Analysis
    std.debug.print("🔬 Phase 3: Semantic Analysis (Type Checking)\n", .{});
    var analyzer = Analyzer.init(allocator);
    defer analyzer.deinit();

    analyzer.analyze(&program) catch |err| {
        std.debug.print("\n❌ Semantic Analysis Error:\n", .{});
        for (analyzer.errors.items) |error_msg| {
            std.debug.print("  • {s}\n", .{error_msg});
        }
        return err;
    };

    if (analyzer.errors.items.len > 0) {
        std.debug.print("\n⚠️  Semantic Analysis Warnings:\n", .{});
        for (analyzer.errors.items) |warning| {
            std.debug.print("  • {s}\n", .{warning});
        }
    }

    std.debug.print("   ✓ Type checking passed\n", .{});

    // Phase 4: Code Generation
    std.debug.print("⚙️  Phase 4: Code Generation (C Code)\n", .{});
    codegen.compileToExecutable(allocator, &program, output_file) catch |err| {
        std.debug.print("\n❌ Code Generation Error: {}\n", .{err});
        return err;
    };

    std.debug.print("\n✅ Compilation successful!\n", .{});
    std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("🎉 Run your program with: ./{s}\n", .{output_file});
    std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
}

fn printUsage() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.writeAll(
        \\
        \\Boemia Script Compiler
        \\
        \\Usage:
        \\  boemia-compiler <input.bs> [-o output]
        \\
        \\Options:
        \\  -o <output>    Specify output executable name (default: output)
        \\
        \\Examples:
        \\  boemia-compiler hello.bs
        \\  boemia-compiler hello.bs -o hello
        \\  boemia-compiler examples/factorial.bs -o factorial
        \\
        \\
    );
}
