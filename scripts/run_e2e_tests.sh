#!/bin/bash

# End-to-End Test Runner for Boemia Script
# Tests compilation and execution of example programs

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
OUTPUT_DIR="$PROJECT_ROOT/test-results"
COMPILER="$PROJECT_ROOT/zig-out/bin/boemia-compiler"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "========================================"
echo "Boemia Script E2E Test Runner"
echo "========================================"
echo "Project Root: $PROJECT_ROOT"
echo "Compiler: $COMPILER"
echo ""

# Check if compiler exists
if [ ! -f "$COMPILER" ]; then
    echo -e "${RED}Error: Compiler not found at $COMPILER${NC}"
    echo "Please run 'zig build' first"
    exit 1
fi

# Check if GCC exists
if ! command -v gcc &> /dev/null; then
    echo -e "${RED}Error: GCC not found${NC}"
    echo "Please install GCC to run E2E tests"
    exit 1
fi

echo "✓ Compiler found"
echo "✓ GCC found"
echo ""

# Function to run a test
run_test() {
    local test_name=$1
    local source_file=$2
    local expected_output=$3
    local check_function=$4

    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo "----------------------------------------"
    echo "Test $TOTAL_TESTS: $test_name"
    echo "Source: $source_file"

    # Compile Boemia Script to C
    if ! "$COMPILER" "$source_file" > "$OUTPUT_DIR/${test_name}_compiler.log" 2>&1; then
        echo -e "${RED}✗ FAILED${NC} - Compilation failed"
        cat "$OUTPUT_DIR/${test_name}_compiler.log"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi

    # Compile C to executable
    if ! gcc "$BUILD_DIR/output.c" -o "$OUTPUT_DIR/${test_name}" -lm > "$OUTPUT_DIR/${test_name}_gcc.log" 2>&1; then
        echo -e "${RED}✗ FAILED${NC} - GCC compilation failed"
        cat "$OUTPUT_DIR/${test_name}_gcc.log"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi

    # Execute the program
    if ! "$OUTPUT_DIR/${test_name}" > "$OUTPUT_DIR/${test_name}_output.txt" 2>&1; then
        echo -e "${RED}✗ FAILED${NC} - Execution failed"
        cat "$OUTPUT_DIR/${test_name}_output.txt"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi

    # Check output
    if [ -n "$check_function" ]; then
        if $check_function "$OUTPUT_DIR/${test_name}_output.txt"; then
            echo -e "${GREEN}✓ PASSED${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            return 0
        else
            echo -e "${RED}✗ FAILED${NC} - Output check failed"
            echo "Expected: $expected_output"
            echo "Actual output:"
            cat "$OUTPUT_DIR/${test_name}_output.txt"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            return 1
        fi
    elif [ -n "$expected_output" ]; then
        if grep -q "$expected_output" "$OUTPUT_DIR/${test_name}_output.txt"; then
            echo -e "${GREEN}✓ PASSED${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            return 0
        else
            echo -e "${RED}✗ FAILED${NC} - Output mismatch"
            echo "Expected: $expected_output"
            echo "Actual output:"
            cat "$OUTPUT_DIR/${test_name}_output.txt"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            return 1
        fi
    else
        # No output check, just verify it ran without crashing
        echo -e "${GREEN}✓ PASSED${NC} - Executed successfully"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    fi
}

# Custom check functions
check_hello() {
    grep -q "Hola" "$1"
}

check_simple() {
    grep -q "42" "$1"
}

check_arrays() {
    grep -q "10" "$1" && grep -q "20" "$1" && grep -q "30" "$1"
}

check_arrays_nested() {
    # Just check it doesn't crash and produces some output
    [ -s "$1" ]
}

check_for_in() {
    local count=$(grep -c "^" "$1")
    [ "$count" -gt 0 ]
}

# Run all tests
echo "========================================"
echo "Running Tests..."
echo "========================================"
echo ""

# Test 1: Hello World
if [ -f "$PROJECT_ROOT/examples/hello.bs" ]; then
    run_test "hello" "$PROJECT_ROOT/examples/hello.bs" "" check_hello
fi

# Test 2: Simple integer
if [ -f "$PROJECT_ROOT/examples/simple.bs" ]; then
    run_test "simple" "$PROJECT_ROOT/examples/simple.bs" "" check_simple
fi

# Test 3: Types
if [ -f "$PROJECT_ROOT/examples/types.bs" ]; then
    run_test "types" "$PROJECT_ROOT/examples/types.bs" "" ""
fi

# Test 4: Conditionals
if [ -f "$PROJECT_ROOT/examples/conditionals.bs" ]; then
    run_test "conditionals" "$PROJECT_ROOT/examples/conditionals.bs" "" ""
fi

# Test 5: Loops
if [ -f "$PROJECT_ROOT/examples/loops.bs" ]; then
    run_test "loops" "$PROJECT_ROOT/examples/loops.bs" "" ""
fi

# Test 6: Array operations
if [ -f "$PROJECT_ROOT/examples/test_array_operations.bs" ]; then
    run_test "array_operations" "$PROJECT_ROOT/examples/test_array_operations.bs" "" check_arrays
fi

# Test 7: Array parsing
if [ -f "$PROJECT_ROOT/examples/test_array_parsing.bs" ]; then
    run_test "array_parsing" "$PROJECT_ROOT/examples/test_array_parsing.bs" "" ""
fi

# Test 8: Complete arrays
if [ -f "$PROJECT_ROOT/examples/test_arrays_complete.bs" ]; then
    run_test "arrays_complete" "$PROJECT_ROOT/examples/test_arrays_complete.bs" "" check_arrays
fi

# Test 9: Nested arrays
if [ -f "$PROJECT_ROOT/examples/test_arrays_nested.bs" ]; then
    run_test "arrays_nested" "$PROJECT_ROOT/examples/test_arrays_nested.bs" "" check_arrays_nested
fi

# Test 10: For-in loops
if [ -f "$PROJECT_ROOT/examples/test_for_in.bs" ]; then
    run_test "for_in" "$PROJECT_ROOT/examples/test_for_in.bs" "" check_for_in
fi

# Summary
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Total Tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    echo "See test-results/ directory for detailed logs"
    exit 1
fi
