const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the boemia-compiler executable
    const exe = b.addExecutable(.{
        .name = "boemia-compiler",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
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

    // Create test executable for unit tests
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
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
