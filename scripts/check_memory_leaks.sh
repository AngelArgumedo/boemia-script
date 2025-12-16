#!/bin/bash

# Memory Leak Detection Script for Boemia Script
# Tests for memory leaks using valgrind (Linux) or leaks (macOS)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
OUTPUT_DIR="$PROJECT_ROOT/memory-test-results"
COMPILER="$PROJECT_ROOT/zig-out/bin/boemia-compiler"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "========================================"
echo "Boemia Script Memory Leak Checker"
echo "========================================"
echo ""

# Check if compiler exists
if [ ! -f "$COMPILER" ]; then
    echo -e "${RED}Error: Compiler not found${NC}"
    exit 1
fi

# Detect OS and leak detection tool
OS_TYPE=$(uname -s)
LEAK_TOOL=""

if [ "$OS_TYPE" = "Linux" ]; then
    if command -v valgrind &> /dev/null; then
        LEAK_TOOL="valgrind"
        echo "Using: Valgrind (Linux)"
    else
        echo -e "${RED}Error: valgrind not found${NC}"
        echo "Install with: sudo apt-get install valgrind"
        exit 1
    fi
elif [ "$OS_TYPE" = "Darwin" ]; then
    LEAK_TOOL="leaks"
    echo "Using: leaks (macOS)"
else
    echo -e "${RED}Unsupported OS: $OS_TYPE${NC}"
    exit 1
fi

echo ""

# Function to check for leaks with valgrind
check_valgrind() {
    local test_name=$1
    local executable=$2

    echo "Running valgrind on $test_name..."

    valgrind --leak-check=full \
             --show-leak-kinds=all \
             --track-origins=yes \
             --error-exitcode=1 \
             --log-file="$OUTPUT_DIR/${test_name}_valgrind.log" \
             "$executable" > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ No leaks detected${NC}"
        return 0
    else
        echo -e "${RED}✗ Memory leaks detected${NC}"
        echo "See $OUTPUT_DIR/${test_name}_valgrind.log for details"
        cat "$OUTPUT_DIR/${test_name}_valgrind.log"
        return 1
    fi
}

# Function to check for leaks with macOS leaks tool
check_leaks() {
    local test_name=$1
    local executable=$2

    echo "Running leaks on $test_name..."

    leaks -atExit -- "$executable" > "$OUTPUT_DIR/${test_name}_leaks.log" 2>&1

    if grep -q "0 leaks for 0 total leaked bytes" "$OUTPUT_DIR/${test_name}_leaks.log"; then
        echo -e "${GREEN}✓ No leaks detected${NC}"
        return 0
    else
        echo -e "${RED}✗ Memory leaks detected${NC}"
        echo "See $OUTPUT_DIR/${test_name}_leaks.log for details"
        grep "leaks for" "$OUTPUT_DIR/${test_name}_leaks.log"
        return 1
    fi
}

# Function to compile and test a source file
test_memory() {
    local test_name=$1
    local source_file=$2

    echo "----------------------------------------"
    echo "Memory Test: $test_name"
    echo "Source: $source_file"

    # Compile Boemia Script
    if ! "$COMPILER" "$source_file" > "$OUTPUT_DIR/${test_name}_compile.log" 2>&1; then
        echo -e "${RED}✗ Compilation failed${NC}"
        return 1
    fi

    # Compile C code with debug symbols
    if ! gcc "$BUILD_DIR/output.c" -o "$OUTPUT_DIR/${test_name}" -lm -g > "$OUTPUT_DIR/${test_name}_gcc.log" 2>&1; then
        echo -e "${RED}✗ GCC compilation failed${NC}"
        return 1
    fi

    # Run leak detector
    if [ "$LEAK_TOOL" = "valgrind" ]; then
        check_valgrind "$test_name" "$OUTPUT_DIR/${test_name}"
    else
        check_leaks "$test_name" "$OUTPUT_DIR/${test_name}"
    fi

    return $?
}

# Counters
TOTAL=0
PASSED=0
FAILED=0

# Test array examples (most likely to have memory issues)
if [ -f "$PROJECT_ROOT/examples/test_arrays_complete.bs" ]; then
    TOTAL=$((TOTAL + 1))
    if test_memory "arrays_complete" "$PROJECT_ROOT/examples/test_arrays_complete.bs"; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
    fi
    echo ""
fi

if [ -f "$PROJECT_ROOT/examples/test_arrays_nested.bs" ]; then
    TOTAL=$((TOTAL + 1))
    if test_memory "arrays_nested" "$PROJECT_ROOT/examples/test_arrays_nested.bs"; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
    fi
    echo ""
fi

if [ -f "$PROJECT_ROOT/examples/test_array_operations.bs" ]; then
    TOTAL=$((TOTAL + 1))
    if test_memory "array_operations" "$PROJECT_ROOT/examples/test_array_operations.bs"; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
    fi
    echo ""
fi

if [ -f "$PROJECT_ROOT/examples/test_for_in.bs" ]; then
    TOTAL=$((TOTAL + 1))
    if test_memory "for_in" "$PROJECT_ROOT/examples/test_for_in.bs"; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
    fi
    echo ""
fi

# Summary
echo "========================================"
echo "Memory Test Summary"
echo "========================================"
echo "Total: $TOTAL"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All memory tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some memory tests failed${NC}"
    echo "See memory-test-results/ directory for details"
    exit 1
fi
