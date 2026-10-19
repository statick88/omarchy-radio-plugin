#!/bin/bash
# Tests for manifest.json validation
# Run with: ./test-manifest.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$SCRIPT_DIR/../manifest.json"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_func="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "  $test_name... "
    
    if $test_func; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "✓ PASS"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo "✗ FAIL"
    fi
}

# ============================================================
# TESTS: Manifest Structure
# ============================================================

test_manifest_exists() {
    [ -f "$MANIFEST" ]
}

test_manifest_is_valid_json() {
    if command -v jq &>/dev/null; then
        jq empty "$MANIFEST" 2>/dev/null
    elif command -v python3 &>/dev/null; then
        python3 -m json.tool "$MANIFEST" > /dev/null 2>&1
    else
        # Basic JSON syntax check
        grep -q "^{" "$MANIFEST" && grep -q "}$" "$MANIFEST"
    fi
}

test_schema_version_present() {
    if command -v jq &>/dev/null; then
        local version=$(jq -r '.schemaVersion' "$MANIFEST")
        [ "$version" = "1" ]
    else
        grep -q '"schemaVersion"[[:space:]]*:[[:space:]]*1' "$MANIFEST"
    fi
}

test_id_present() {
    if command -v jq &>/dev/null; then
        local id=$(jq -r '.id' "$MANIFEST")
        [ -n "$id" ] && [ "$id" != "null" ]
    else
        grep -q '"id"' "$MANIFEST"
    fi
}

test_id_format_valid() {
    # ID should be like "omarchy.radio" or "user.pluginname"
    local id
    if command -v jq &>/dev/null; then
        id=$(jq -r '.id' "$MANIFEST")
    else
        id=$(grep '"id"' "$MANIFEST" | head -1 | sed 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    fi
    
    # Check format: alphanumeric with dots and hyphens
    echo "$id" | grep -qE '^[a-zA-Z0-9]+([._-][a-zA-Z0-9]+)*$'
}

test_name_present() {
    if command -v jq &>/dev/null; then
        local name=$(jq -r '.name' "$MANIFEST")
        [ -n "$name" ] && [ "$name" != "null" ]
    else
        grep -q '"name"' "$MANIFEST"
    fi
}

test_version_present() {
    if command -v jq &>/dev/null; then
        local version=$(jq -r '.version' "$MANIFEST")
        [ -n "$version" ] && [ "$version" != "null" ]
    else
        grep -q '"version"' "$MANIFEST"
    fi
}

test_version_semver_format() {
    # Version should be semver: X.Y.Z
    local version
    if command -v jq &>/dev/null; then
        version=$(jq -r '.version' "$MANIFEST")
    else
        version=$(grep '"version"' "$MANIFEST" | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    fi
    
    echo "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'
}

test_kinds_present() {
    if command -v jq &>/dev/null; then
        local kinds=$(jq -r '.kinds' "$MANIFEST")
        [ -n "$kinds" ] && [ "$kinds" != "null" ]
    else
        grep -q '"kinds"' "$MANIFEST"
    fi
}

test_kinds_is_array() {
    if command -v jq &>/dev/null; then
        jq -e '.kinds | type == "array"' "$MANIFEST" 2>/dev/null
    else
        # Check for array syntax
        grep -A1 '"kinds"' "$MANIFEST" | grep -q '\['
    fi
}

test_entry_points_present() {
    if command -v jq &>/dev/null; then
        local ep=$(jq -r '.entryPoints' "$MANIFEST")
        [ -n "$ep" ] && [ "$ep" != "null" ]
    else
        grep -q '"entryPoints"' "$MANIFEST"
    fi
}

test_bar_widget_present() {
    if command -v jq &>/dev/null; then
        local bw=$(jq -r '.entryPoints.barWidget' "$MANIFEST")
        [ -n "$bw" ] && [ "$bw" != "null" ]
    else
        grep -q '"barWidget"' "$MANIFEST"
    fi
}

test_bar_widget_file_exists() {
    local bw_file
    if command -v jq &>/dev/null; then
        bw_file=$(jq -r '.entryPoints.barWidget' "$MANIFEST")
    else
        bw_file=$(grep '"barWidget"' "$MANIFEST" | sed 's/.*"barWidget"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    fi
    
    # Check file exists relative to manifest
    [ -f "$SCRIPT_DIR/../$bw_file" ]
}

test_bar_widget_config_present() {
    if command -v jq &>/dev/null; then
        local bw_config=$(jq -r '.barWidget' "$MANIFEST")
        [ -n "$bw_config" ] && [ "$bw_config" != "null" ]
    else
        grep -q '"barWidget"[[:space:]]*:[[:space:]]*{' "$MANIFEST"
    fi
}

test_bar_widget_display_name() {
    if command -v jq &>/dev/null; then
        local display_name=$(jq -r '.barWidget.displayName' "$MANIFEST")
        [ -n "$display_name" ] && [ "$display_name" != "null" ]
    else
        grep -q '"displayName"' "$MANIFEST"
    fi
}

test_bar_widget_category_present() {
    if command -v jq &>/dev/null; then
        local category=$(jq -r '.barWidget.category' "$MANIFEST")
        [ -n "$category" ] && [ "$category" != "null" ]
    else
        grep -q '"category"' "$MANIFEST"
    fi
}

test_defaults_present() {
    if command -v jq &>/dev/null; then
        local defaults=$(jq -r '.barWidget.defaults' "$MANIFEST")
        [ -n "$defaults" ] && [ "$defaults" != "null" ]
    else
        grep -q '"defaults"' "$MANIFEST"
    fi
}

test_schema_present() {
    if command -v jq &>/dev/null; then
        local schema=$(jq -r '.barWidget.schema' "$MANIFEST")
        [ -n "$schema" ] && [ "$schema" != "null" ]
    else
        grep -q '"schema"' "$MANIFEST"
    fi
}

test_schema_is_array() {
    if command -v jq &>/dev/null; then
        jq -e '.barWidget.schema | type == "array"' "$MANIFEST" 2>/dev/null
    else
        grep -A1 '"schema"' "$MANIFEST" | grep -q '\['
    fi
}

test_schema_items_have_required_fields() {
    if command -v jq &>/dev/null; then
        # Each schema item should have key, type, label
        local valid=$(jq -e '.barWidget.schema | all(.[]; has("key") and has("type") and has("label"))' "$MANIFEST" 2>/dev/null)
        [ "$valid" = "true" ]
    else
        # Basic check for key, type, label patterns
        grep -q '"key"' "$MANIFEST" && grep -q '"type"' "$MANIFEST" && grep -q '"label"' "$MANIFEST"
    fi
}

# ============================================================
# TESTS: Overlay Plugin Structure
# ============================================================

test_overlay_entry_point_exists() {
    # Check if overlay is declared
    if command -v jq &>/dev/null; then
        local overlay=$(jq -r '.entryPoints.overlay' "$MANIFEST" 2>/dev/null)
        if [ -n "$overlay" ] && [ "$overlay" != "null" ]; then
            [ -f "$SCRIPT_DIR/../$overlay" ]
        else
            # Overlay is optional, so pass if not present
            return 0
        fi
    else
        # Check if overlay is mentioned
        grep -q '"overlay"' "$MANIFEST" || return 0
        # If present, check file exists
        local overlay_file=$(grep '"overlay"' "$MANIFEST" | sed 's/.*"overlay"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        [ -f "$SCRIPT_DIR/../$overlay_file" ]
    fi
}

test_kinds_include_bar_widget() {
    if command -v jq &>/dev/null; then
        jq -e '.kinds | index("bar-widget")' "$MANIFEST" 2>/dev/null
    else
        grep -q '"bar-widget"' "$MANIFEST"
    fi
}

# ============================================================
# Run all tests
# ============================================================

echo "Running manifest.json validation tests..."
echo ""

run_test "Manifest file exists" test_manifest_exists
run_test "Manifest is valid JSON" test_manifest_is_valid_json
run_test "Schema version is present" test_schema_version_present
run_test "ID is present" test_id_present
run_test "ID format is valid" test_id_format_valid
run_test "Name is present" test_name_present
run_test "Version is present" test_version_present
run_test "Version follows semver" test_version_semver_format
run_test "Kinds is present" test_kinds_present
run_test "Kinds is an array" test_kinds_is_array
run_test "Entry points are present" test_entry_points_present
run_test "Bar widget entry point exists" test_bar_widget_present
run_test "Bar widget file exists" test_bar_widget_file_exists
run_test "Bar widget config exists" test_bar_widget_config_present
run_test "Bar widget has display name" test_bar_widget_display_name
run_test "Bar widget has category" test_bar_widget_category_present
run_test "Defaults are present" test_defaults_present
run_test "Schema is present" test_schema_present
run_test "Schema is an array" test_schema_is_array
run_test "Schema items have required fields" test_schema_items_have_required_fields
run_test "Overlay entry point file exists" test_overlay_entry_point_exists
run_test "Kinds include bar-widget" test_kinds_include_bar_widget

# Summary
echo ""
echo "========================================="
echo "Test Results:"
echo "  Total: $TESTS_RUN"
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"
echo "========================================="

if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
fi

exit 0