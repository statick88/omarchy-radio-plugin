#!/bin/bash
# Main test runner for omarchy.radio
# Runs all test suites in order: TDD → Integration → E2E

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counters
TOTAL_RUN=0
TOTAL_PASSED=0
TOTAL_FAILED=0
SUITE_RESULTS=()

print_header() {
    echo ""
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo ""
}

print_suite_result() {
    local suite_name="$1"
    local passed="$2"
    local failed="$3"
    
    SUITE_RESULTS+=("$suite_name:$passed:$failed")
    
    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}✓ $suite_name: All tests passed${NC}"
    else
        echo -e "${RED}✗ $suite_name: $failed test(s) failed${NC}"
    fi
}

# ============================================================
# Phase 1: TDD Unit Tests
# ============================================================

print_header "Phase 1: TDD Unit Tests"

if [ -x "$SCRIPT_DIR/test-radio-control.sh" ]; then
    echo "Running radio-control.sh unit tests..."
    echo ""
    
    if "$SCRIPT_DIR/test-radio-control.sh"; then
        TOTAL_PASSED=$((TOTAL_PASSED + 1))
        print_suite_result "radio-control.sh" 1 0
    else
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
        print_suite_result "radio-control.sh" 0 1
    fi
else
    echo -e "${YELLOW}⚠ test-radio-control.sh not found or not executable${NC}"
fi

echo ""

if [ -x "$SCRIPT_DIR/test-manifest.sh" ]; then
    echo "Running manifest.json validation tests..."
    echo ""
    
    if "$SCRIPT_DIR/test-manifest.sh"; then
        TOTAL_PASSED=$((TOTAL_PASSED + 1))
        print_suite_result "manifest.json" 1 0
    else
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
        print_suite_result "manifest.json" 0 1
    fi
else
    echo -e "${YELLOW}⚠ test-manifest.sh not found or not executable${NC}"
fi

# ============================================================
# Phase 2: Integration Tests
# ============================================================

print_header "Phase 2: Integration Tests"

if [ -x "$SCRIPT_DIR/test-gadget-stations.sh" ]; then
    echo "Running SketchyBar gadget station tests..."
    echo ""

    if "$SCRIPT_DIR/test-gadget-stations.sh"; then
        TOTAL_PASSED=$((TOTAL_PASSED + 1))
        print_suite_result "gadget stations" 1 0
    else
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
        print_suite_result "gadget stations" 0 1
    fi
else
    echo -e "${YELLOW}⚠ test-gadget-stations.sh not found or not executable${NC}"
fi

echo ""

if [ -x "$SCRIPT_DIR/test-qml-integration.sh" ]; then
    echo "Running QML integration tests..."
    echo ""
    
    if "$SCRIPT_DIR/test-qml-integration.sh"; then
        TOTAL_PASSED=$((TOTAL_PASSED + 1))
        print_suite_result "QML Integration" 1 0
    else
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
        print_suite_result "QML Integration" 0 1
    fi
else
    echo -e "${YELLOW}⚠ test-qml-integration.sh not found or not executable${NC}"
fi

# ============================================================
# Phase 3: E2E Tests
# ============================================================

print_header "Phase 3: E2E Tests"

if [ -x "$SCRIPT_DIR/test-e2e.sh" ]; then
    echo "Running E2E workflow tests..."
    echo ""
    
    if "$SCRIPT_DIR/test-e2e.sh"; then
        TOTAL_PASSED=$((TOTAL_PASSED + 1))
        print_suite_result "E2E Workflow" 1 0
    else
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
        print_suite_result "E2E Workflow" 0 1
    fi
else
    echo -e "${YELLOW}⚠ test-e2e.sh not found or not executable${NC}"
fi

# ============================================================
# Final Summary
# ============================================================

print_header "Test Summary"

echo "Test Suite Results:"
echo ""

for result in "${SUITE_RESULTS[@]}"; do
    IFS=':' read -r name passed failed <<< "$result"
    
    if [ "$failed" -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} $name"
    else
        echo -e "  ${RED}✗${NC} $name"
    fi
done

echo ""
echo "-----------------------------------------"

TOTAL_SUITES=${#SUITE_RESULTS[@]}
PASSED_SUITES=0
FAILED_SUITES=0

for result in "${SUITE_RESULTS[@]}"; do
    IFS=':' read -r name passed failed <<< "$result"
    
    if [ "$failed" -eq 0 ]; then
        PASSED_SUITES=$((PASSED_SUITES + 1))
    else
        FAILED_SUITES=$((FAILED_SUITES + 1))
    fi
done

echo ""
echo -e "Total Suites: $TOTAL_SUITES"
echo -e "${GREEN}Passed: $PASSED_SUITES${NC}"

if [ $FAILED_SUITES -gt 0 ]; then
    echo -e "${RED}Failed: $FAILED_SUITES${NC}"
else
    echo -e "Failed: $FAILED_SUITES"
fi

echo ""

if [ $FAILED_SUITES -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED!${NC}"
    echo ""
    echo -e "${CYAN}Ready for RDD verification...${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed. Please fix issues before RDD.${NC}"
    exit 1
fi