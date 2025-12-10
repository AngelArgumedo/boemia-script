// Test runner that imports all test files
// Run with: zig build test

test {
    // Import all test files to run their tests
    _ = @import("lexer_test.zig");
    _ = @import("parser_test.zig");
    _ = @import("analyzer_test.zig");
    _ = @import("integration_test.zig");
}
