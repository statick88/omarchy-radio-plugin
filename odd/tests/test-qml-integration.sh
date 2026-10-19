#!/bin/bash
# Integration tests for QML files
# Run with: ./test-qml-integration.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$SCRIPT_DIR/.."

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
# TESTS: File Structure
# ============================================================

test_bar_widget_exists() {
    [ -f "$PLUGIN_DIR/BarWidget.qml" ]
}

test_panel_exists() {
    [ -f "$PLUGIN_DIR/Panel.qml" ]
}

test_bar_widget_not_empty() {
    [ -s "$PLUGIN_DIR/BarWidget.qml" ]
}

test_panel_not_empty() {
    [ -s "$PLUGIN_DIR/Panel.qml" ]
}

# ============================================================
# TESTS: QML Syntax (Basic)
# ============================================================

test_bar_widget_has_pragma() {
    head -1 "$PLUGIN_DIR/BarWidget.qml" | grep -q "pragma ComponentBehavior"
}

test_bar_widget_has_imports() {
    grep -q "^import" "$PLUGIN_DIR/BarWidget.qml"
}

test_bar_widget_has_component() {
    grep -q "Ui.BarWidget\|BarWidget {" "$PLUGIN_DIR/BarWidget.qml"
}

test_bar_widget_has_module_name() {
    grep -q "moduleName" "$PLUGIN_DIR/BarWidget.qml"
}

test_bar_widget_has_implicit_dimensions() {
    grep -q "implicitWidth" "$PLUGIN_DIR/BarWidget.qml" && \
    grep -q "implicitHeight" "$PLUGIN_DIR/BarWidget.qml"
}

test_bar_widget_balanced_braces() {
    # Count opening and closing braces
    local open=$(grep -o '{' "$PLUGIN_DIR/BarWidget.qml" | wc -l)
    local close=$(grep -o '}' "$PLUGIN_DIR/BarWidget.qml" | wc -l)
    [ "$open" -eq "$close" ]
}

test_panel_has_pragma() {
    head -1 "$PLUGIN_DIR/Panel.qml" | grep -q "pragma ComponentBehavior"
}

test_panel_has_imports() {
    grep -q "^import" "$PLUGIN_DIR/Panel.qml"
}

test_panel_has_component() {
    grep -q "Ui.Panel\|Panel {" "$PLUGIN_DIR/Panel.qml"
}

test_panel_balanced_braces() {
    local open=$(grep -o '{' "$PLUGIN_DIR/Panel.qml" | wc -l)
    local close=$(grep -o '}' "$PLUGIN_DIR/Panel.qml" | wc -l)
    [ "$open" -eq "$close" ]
}

# ============================================================
# TESTS: Required Elements
# ============================================================

test_bar_widget_has_button() {
    grep -q "BarIconButton\|MouseArea\|Button" "$PLUGIN_DIR/BarWidget.qml"
}

test_bar_widget_has_text_display() {
    # The label is either a direct Text element or delegated to the shared
    # Ui.WidgetButton (which owns text rendering for bar entries).
    grep -q "Text {\|WidgetButton" "$PLUGIN_DIR/BarWidget.qml"
}

test_bar_widget_has_tooltip() {
    grep -q "tooltipText\|tooltip" "$PLUGIN_DIR/BarWidget.qml"
}

test_bar_widget_has_colors() {
    # The state color is either a direct `color:` or the shared component's
    # `foreground:` token.
    grep -q "color:\|foreground:" "$PLUGIN_DIR/BarWidget.qml"
}

test_bar_widget_has_font() {
    # Either the widget sets the font itself, or it delegates the bar font by
    # handing the bar to the shared component.
    grep -q "font.family\|fontFamily\|bar: root.bar" "$PLUGIN_DIR/BarWidget.qml"
}

test_panel_has_panel_component() {
    # Panel should be the shell's Panel component (either `Ui.Panel` or the
    # unaliased `Panel {`); the bare `Loader`-only form is the regression.
    grep -q "Ui.Panel\|Panel {" "$PLUGIN_DIR/Panel.qml"
}

test_panel_has_stations_config() {
    grep -q "stations\|station" "$PLUGIN_DIR/Panel.qml"
}

test_panel_has_volume_control() {
    grep -q "volume\|Volume" "$PLUGIN_DIR/Panel.qml"
}

test_panel_has_spacing() {
    # The panel lays out its sections with explicit spacing instead of
    # implicit gaps.
    grep -q "spacing:" "$PLUGIN_DIR/Panel.qml"
}

# ============================================================
# TESTS: Functionality Integration
# ============================================================

test_bar_widget_references_panel() {
    grep -q "Panel.qml\|panelLoader" "$PLUGIN_DIR/BarWidget.qml"
}

test_bar_widget_has_setting_function() {
    grep -q "setting(" "$PLUGIN_DIR/BarWidget.qml"
}

test_panel_has_file_io() {
    grep -q "FileView\|File" "$PLUGIN_DIR/Panel.qml"
}

test_panel_has_process() {
    grep -q "Process" "$PLUGIN_DIR/Panel.qml"
}

test_panel_has_mp_v_integration() {
    grep -q "mpv" "$PLUGIN_DIR/Panel.qml" || \
    grep -q "radio-control" "$PLUGIN_DIR/Panel.qml"
}

test_panel_has_station_colors() {
    # The active station is highlighted with the accent token.
    grep -q "stationColors\|Color.accent" "$PLUGIN_DIR/Panel.qml"
}

test_panel_has_keyboard_handling() {
    grep -q "Keys\|Keyboard\|onTextKey\|onReturnRequested" "$PLUGIN_DIR/Panel.qml"
}

# ============================================================
# TESTS: UI/UX Quality
# ============================================================

test_panel_has_visual_styling() {
    # Panel should have color properties or styling
    grep -q "color:" "$PLUGIN_DIR/Panel.qml"
}

test_panel_has_anchors() {
    grep -q "anchors" "$PLUGIN_DIR/Panel.qml"
}

test_panel_has_layout() {
    # Either the Qt Layout types or the plain Column/Row containers.
    grep -q "RowLayout\|ColumnLayout\|Layout\|Column {\|Row {" "$PLUGIN_DIR/Panel.qml"
}

test_panel_has_hover() {
    grep -q "hoverEnabled\|containsMouse" "$PLUGIN_DIR/Panel.qml"
}

test_panel_has_animation() {
    grep -q "Animation\|Behavior" "$PLUGIN_DIR/Panel.qml"
}

# ============================================================
# TESTS: Plugin Integration
# ============================================================

test_bar_widget_module_name_matches_manifest() {
    # Extract module name from BarWidget.qml
    local bar_module=$(grep "moduleName:" "$PLUGIN_DIR/BarWidget.qml" | head -1 | sed 's/.*moduleName:[[:space:]]*"\([^"]*\)".*/\1/')
    
    # Extract id from manifest.json
    local manifest_id=$(grep '"id"' "$PLUGIN_DIR/manifest.json" | head -1 | sed 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    
    # Compare
    [ "$bar_module" = "$manifest_id" ]
}

test_panel_module_name_matches_manifest() {
    # Extract module name from Panel.qml
    local panel_module=$(grep "moduleName:" "$PLUGIN_DIR/Panel.qml" | head -1 | sed 's/.*moduleName:[[:space:]]*"\([^"]*\)".*/\1/')
    
    # Extract id from manifest.json
    local manifest_id=$(grep '"id"' "$PLUGIN_DIR/manifest.json" | head -1 | sed 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    
    # Compare
    [ "$panel_module" = "$manifest_id" ]
}

test_files_referenced_in_manifest_exist() {
    # Check all QML files referenced in manifest exist
    local files=$(grep -oE '"[^"]*\.qml"' "$PLUGIN_DIR/manifest.json" | tr -d '"')
    for file in $files; do
        [ -f "$PLUGIN_DIR/$file" ] || return 1
    done
    return 0
}

# ============================================================
# TESTS: Code Quality
# ============================================================

test_bar_widget_no_syntax_errors_basic() {
    # Basic check: no obvious syntax errors
    # Check for lines that end with colon (potential missing value)
    ! grep -E 'property[^:]*:\s*$' "$PLUGIN_DIR/BarWidget.qml" | grep -v "//" | grep -q "[a-zA-Z]"
}

test_panel_no_syntax_errors_basic() {
    ! grep -E 'property[^:]*:\s*$' "$PLUGIN_DIR/Panel.qml" | grep -v "//" | grep -q "[a-zA-Z]"
}

test_bar_widget_no_trailing_whitespace_issues() {
    # Check for lines with only whitespace (excluding empty lines)
    local bad_lines=$(grep -E '^\s+$' "$PLUGIN_DIR/BarWidget.qml" | wc -l)
    [ "$bad_lines" -eq 0 ]
}

test_proper_indentation() {
    # Check that file uses consistent indentation (spaces, not tabs)
    local tab_count=$(grep -P '\t' "$PLUGIN_DIR/BarWidget.qml" | wc -l)
    [ "$tab_count" -eq 0 ]
}

# ============================================================
# Run all tests
# ============================================================

echo "Running QML integration tests..."
echo ""

run_test "BarWidget.qml exists" test_bar_widget_exists
run_test "Panel.qml exists" test_panel_exists
run_test "BarWidget.qml is not empty" test_bar_widget_not_empty
run_test "Panel.qml is not empty" test_panel_not_empty

run_test "BarWidget has pragma directive" test_bar_widget_has_pragma
run_test "BarWidget has imports" test_bar_widget_has_imports
run_test "BarWidget has component" test_bar_widget_has_component
run_test "BarWidget has module name" test_bar_widget_has_module_name
run_test "BarWidget has implicit dimensions" test_bar_widget_has_implicit_dimensions
run_test "BarWidget has balanced braces" test_bar_widget_balanced_braces

run_test "Panel has pragma directive" test_panel_has_pragma
run_test "Panel has imports" test_panel_has_imports
run_test "Panel has component" test_panel_has_component
run_test "Panel has balanced braces" test_panel_balanced_braces

run_test "BarWidget has button" test_bar_widget_has_button
run_test "BarWidget has text display" test_bar_widget_has_text_display
run_test "BarWidget has tooltip" test_bar_widget_has_tooltip
run_test "BarWidget has colors" test_bar_widget_has_colors
run_test "BarWidget has font" test_bar_widget_has_font

run_test "Panel has panel component" test_panel_has_panel_component
run_test "Panel has stations config" test_panel_has_stations_config
run_test "Panel has volume control" test_panel_has_volume_control
run_test "Panel has spacing" test_panel_has_spacing

run_test "BarWidget references panel" test_bar_widget_references_panel
run_test "BarWidget has setting function" test_bar_widget_has_setting_function
run_test "Panel has file I/O" test_panel_has_file_io
run_test "Panel has process" test_panel_has_process
run_test "Panel has mpv integration" test_panel_has_mp_v_integration
run_test "Panel has station colors" test_panel_has_station_colors
run_test "Panel has keyboard handling" test_panel_has_keyboard_handling

run_test "Panel has visual styling" test_panel_has_visual_styling
run_test "Panel has anchors" test_panel_has_anchors
run_test "Panel has layout" test_panel_has_layout
run_test "Panel has hover" test_panel_has_hover
run_test "Panel has animation" test_panel_has_animation

run_test "BarWidget module name matches manifest" test_bar_widget_module_name_matches_manifest
run_test "Panel module name matches manifest" test_panel_module_name_matches_manifest
run_test "Files referenced in manifest exist" test_files_referenced_in_manifest_exist

run_test "BarWidget has no basic syntax errors" test_bar_widget_no_syntax_errors_basic
run_test "Panel has no basic syntax errors" test_panel_no_syntax_errors_basic
run_test "BarWidget has no trailing whitespace issues" test_bar_widget_no_trailing_whitespace_issues
run_test "Code uses proper indentation (no tabs)" test_proper_indentation

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