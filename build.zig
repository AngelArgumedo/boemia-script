const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the boemia-compiler executable
    const exe = b.addExecutable(.{
        .name = "boemia-compiler",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Install the executable
    b.installArtifact(exe);

    // Create run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    // Allow passing arguments to the compiler
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the Boemia Script compiler");
    run_step.dependOn(&run_cmd.step);

    // Create modules for source files with proper dependencies
    const token_module = b.createModule(.{
        .root_source_file = b.path("src/token.zig"),
        .target = target,
        .optimize = optimize,
    });

    const ast_module = b.createModule(.{
        .root_source_file = b.path("src/ast.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lexer_module = b.createModule(.{
        .root_source_file = b.path("src/lexer.zig"),
        .target = target,
        .optimize = optimize,
    });
    lexer_module.addImport("token.zig", token_module);

    const parser_module = b.createModule(.{
        .root_source_file = b.path("src/parser.zig"),
        .target = target,
        .optimize = optimize,
    });
    parser_module.addImport("token.zig", token_module);
    parser_module.addImport("lexer.zig", lexer_module);
    parser_module.addImport("ast.zig", ast_module);

    const analyzer_module = b.createModule(.{
        .root_source_file = b.path("src/analyzer.zig"),
        .target = target,
        .optimize = optimize,
    });
    analyzer_module.addImport("ast.zig", ast_module);

    const codegen_module = b.createModule(.{
        .root_source_file = b.path("src/codegen.zig"),
        .target = target,
        .optimize = optimize,
    });
    codegen_module.addImport("ast.zig", ast_module);

    // Create test module with all imports
    const test_module = b.createModule(.{
        .root_source_file = b.path("tests/test_runner.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_module.addImport("token.zig", token_module);
    test_module.addImport("lexer.zig", lexer_module);
    test_module.addImport("parser.zig", parser_module);
    test_module.addImport("ast.zig", ast_module);
    test_module.addImport("analyzer.zig", analyzer_module);
    test_module.addImport("codegen.zig", codegen_module);

    const unit_tests = b.addTest(.{
        .root_module = test_module,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    // Test step
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // Create a step to compile example files
    const example_step = b.step("example", "Compile and run example programs");

    const compile_example = b.addSystemCommand(&[_][]const u8{
        "./zig-out/bin/boemia-compiler",
        "examples/hello.bs",
        "-o",
        "hello",
    });
    compile_example.step.dependOn(b.getInstallStep());
    example_step.dependOn(&compile_example.step);
}
