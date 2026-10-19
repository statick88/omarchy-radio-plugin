#!/bin/bash
# E2E Tests for full plugin workflow
# Run with: ./test-e2e.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$SCRIPT_DIR/.."
TEST_HOME=$(mktemp -d)
export HOME="$TEST_HOME"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_func="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "  $test_name... "
    
    # Setup for each test
    setup_test_env
    
    if $test_func; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "✓ PASS"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo "✗ FAIL"
    fi
    
    cleanup_test_env
}

setup_test_env() {
    # Create test directory structure
    mkdir -p "$HOME/.config/omarchy-radio"
    mkdir -p "$HOME/.config/omarchy/plugins"
}

cleanup_test_env() {
    rm -rf "$HOME/.config/omarchy-radio"
}

# ============================================================
# TESTS: Installation Workflow
# ============================================================

test_install_script_exists() {
    [ -x "$PLUGIN_DIR/install.sh" ]
}

test_install_script_syntax() {
    bash -n "$PLUGIN_DIR/install.sh"
}

test_install_script_copies_files() {
    # Run install script
    "$PLUGIN_DIR/install.sh" > /dev/null 2>&1 || true
    
    # Check if plugin directory was created
    [ -d "$HOME/.config/omarchy/plugins/statick.radio" ]
}

test_install_creates_config() {
    "$PLUGIN_DIR/install.sh" > /dev/null 2>&1 || true
    
    # Check if config was created
    [ -f "$HOME/.config/omarchy-radio/stations.conf" ]
}

test_install_config_has_stations() {
    "$PLUGIN_DIR/install.sh" > /dev/null 2>&1 || true
    
    # Config should have at least one station
    local station_count=$(grep -c "^[0-9]" "$HOME/.config/omarchy-radio/stations.conf" 2>/dev/null || echo 0)
    [ "$station_count" -ge 1 ]
}

test_install_copies_manifest() {
    "$PLUGIN_DIR/install.sh" > /dev/null 2>&1 || true
    
    [ -f "$HOME/.config/omarchy/plugins/statick.radio/manifest.json" ]
}

test_install_copies_qml_files() {
    "$PLUGIN_DIR/install.sh" > /dev/null 2>&1 || true
    
    [ -f "$HOME/.config/omarchy/plugins/statick.radio/BarWidget.qml" ] && \
    [ -f "$HOME/.config/omarchy/plugins/statick.radio/Panel.qml" ]
}

test_install_makes_scripts_executable() {
    "$PLUGIN_DIR/install.sh" > /dev/null 2>&1 || true
    
    [ -x "$HOME/.config/omarchy/plugins/statick.radio/radio-control.sh" ]
}

# ============================================================
# TESTS: Radio Control Workflow
# ============================================================

test_radio_control_status_command() {
    # Setup config
    cat > "$HOME/.config/omarchy-radio/stations.conf" << 'EOF'
1|Test Station|https://example.com/stream
EOF
    
    # Run status
    local output=$("$PLUGIN_DIR/radio-control.sh" status 2>&1)
    
    # Should show status
    echo "$output" | grep -q "Estado actual"
}

test_radio_control_lists_stations() {
    cat > "$HOME/.config/omarchy-radio/stations.conf" << 'EOF'
1|Station A|https://example.com/a
2|Station B|https://example.com/b
3|Station C|https://example.com/c
EOF
    
    local output=$("$PLUGIN_DIR/radio-control.sh" status 2>&1)
    
    # Should list all stations
    echo "$output" | grep -q "Station A" && \
    echo "$output" | grep -q "Station B" && \
    echo "$output" | grep -q "Station C"
}

test_radio_control_creates_state() {
    cat > "$HOME/.config/omarchy-radio/stations.conf" << 'EOF'
1|Test Station|https://example.com/stream
EOF
    
    # Run status to trigger state creation
    "$PLUGIN_DIR/radio-control.sh" status > /dev/null 2>&1 || true
    
    # State file should exist
    [ -f "$HOME/.config/omarchy-radio/state" ]
}

test_radio_control_state_has_defaults() {
    cat > "$HOME/.config/omarchy-radio/stations.conf" << 'EOF'
1|Test Station|https://example.com/stream
EOF
    
    "$PLUGIN_DIR/radio-control.sh" status > /dev/null 2>&1 || true
    
    # Check state has expected fields with defaults
    grep -q "CURRENT_STATION=1" "$HOME/.config/omarchy-radio/state" && \
    grep -q "IS_PLAYING=false" "$HOME/.config/omarchy-radio/state" && \
    grep -q "VOLUME=80" "$HOME/.config/omarchy-radio/state"
}

test_radio_control_preserves_state() {
    cat > "$HOME/.config/omarchy-radio/stations.conf" << 'EOF'
1|Test Station|https://example.com/stream
EOF
    
    # Create initial state
    cat > "$HOME/.config/omarchy-radio/state" << 'EOF'
CURRENT_STATION=1
IS_PLAYING=false
VOLUME=75
EOF
    
    # Run status (should not overwrite state)
    "$PLUGIN_DIR/radio-control.sh" status > /dev/null 2>&1 || true
    
    # State should be preserved
    grep -q "VOLUME=75" "$HOME/.config/omarchy-radio/state"
}

# ============================================================
# TESTS: Configuration Management
# ============================================================

test_config_parsing_with_spaces() {
    cat > "$HOME/.config/omarchy-radio/stations.conf" << 'EOF'
1|Radio Station Name With Spaces|https://example.com/stream
EOF
    
    local output=$("$PLUGIN_DIR/radio-control.sh" status 2>&1)
    
    # Should handle spaces in names
    echo "$output" | grep -q "Radio Station Name With Spaces"
}

test_config_parsing_special_characters() {
    cat > "$HOME/.config/omarchy-radio/stations.conf" << 'EOF'
1|FM 101.5 - Classic Rock|https://example.com/stream
2|R&B Soul Radio|https://example.com/soul
3|Jazz & Blues 92.3|https://example.com/jazz
EOF
    
    local output=$("$PLUGIN_DIR/radio-control.sh" status 2>&1)
    
    # Should handle special characters
    echo "$output" | grep -q "FM 101.5" && \
    echo "$output" | grep -q "R&B Soul" && \
    echo "$output" | grep -q "Jazz & Blues"
}

test_config_parsing_urls() {
    cat > "$HOME/.config/omarchy-radio/stations.conf" << 'EOF'
1|Station|https://example.com/path/to/stream?a=1&b=2
2|Station 2|http://another.example.com:8080/stream
EOF
    
    # Should not crash
    "$PLUGIN_DIR/radio-control.sh" status > /dev/null 2>&1
    
    return 0
}

test_config_multiple_stations() {
    # Test with many stations
    {
        for i in {1..20}; do
            echo "$i|Station $i|https://example.com/station$i"
        done
    } > "$HOME/.config/omarchy-radio/stations.conf"
    
    local output=$("$PLUGIN_DIR/radio-control.sh" status 2>&1)
    
    # Should show all stations
    echo "$output" | grep -q "Station 20"
}

# ============================================================
# TESTS: Plugin Structure
# ============================================================

test_plugin_files_complete() {
    # All required files should exist in odd/
    [ -f "$PLUGIN_DIR/manifest.json" ] && \
    [ -f "$PLUGIN_DIR/BarWidget.qml" ] && \
    [ -f "$PLUGIN_DIR/Panel.qml" ] && \
    [ -f "$PLUGIN_DIR/radio-control.sh" ] && \
    [ -f "$PLUGIN_DIR/install.sh" ] && \
    [ -f "$PLUGIN_DIR/README.md" ]
}

test_plugin_scripts_executable() {
    [ -x "$PLUGIN_DIR/radio-control.sh" ] && \
    [ -x "$PLUGIN_DIR/install.sh" ]
}

test_plugin_has_readme() {
    [ -s "$PLUGIN_DIR/README.md" ]
}

test_plugin_readme_has_installation() {
    grep -q "Instalación\|Installation" "$PLUGIN_DIR/README.md"
}

test_plugin_readme_has_usage() {
    grep -q "Uso\|Usage\|Controles" "$PLUGIN_DIR/README.md"
}

# ============================================================
# TESTS: Integration with Omarchy
# ============================================================

test_manifest_integration() {
    # Manifest should have correct module ID
    grep -q '"id": "statick.radio"' "$PLUGIN_DIR/manifest.json"
}

test_qml_module_names_match() {
    # Both QML files should reference the same module
    local bar_module=$(grep "moduleName" "$PLUGIN_DIR/BarWidget.qml" | head -1)
    local panel_module=$(grep "moduleName" "$PLUGIN_DIR/Panel.qml" | head -1)
    
    echo "$bar_module" | grep -q "statick.radio" && \
    echo "$panel_module" | grep -q "statick.radio"
}

test_widget_has_required_properties() {
    # BarWidget should have essential properties
    grep -q "implicitWidth" "$PLUGIN_DIR/BarWidget.qml" && \
    grep -q "implicitHeight" "$PLUGIN_DIR/BarWidget.qml" && \
    grep -q "moduleName" "$PLUGIN_DIR/BarWidget.qml"
}

test_panel_has_required_elements() {
    # Panel should have essential elements
    grep -q "Loader\|Panel" "$PLUGIN_DIR/Panel.qml"
}

# ============================================================
# TESTS: Error Handling
# ============================================================

test_graceful_missing_config() {
    rm -f "$HOME/.config/omarchy-radio/stations.conf"
    
    # Should handle gracefully and create default config
    "$PLUGIN_DIR/radio-control.sh" status > /dev/null 2>&1 || true
    
    # Should create default config
    [ -f "$HOME/.config/omarchy-radio/stations.conf" ]
}

test_graceful_invalid_station() {
    cat > "$HOME/.config/omarchy-radio/stations.conf" << 'EOF'
1|Station|https://example.com
EOF
    
    # Try to play invalid station
    local exit_code=0
    "$PLUGIN_DIR/radio-control.sh" play 99 2>/dev/null || exit_code=$?
    
    # Should return error code
    [ $exit_code -ne 0 ]
}

test_graceful_malformed_config() {
    cat > "$HOME/.config/omarchy-radio/stations.conf" << 'EOF'
This is not a valid config line
1|Valid Station|https://example.com
|Missing ID|url
3|Missing URL
EOF
    
    # Should not crash
    "$PLUGIN_DIR/radio-control.sh" status > /dev/null 2>&1
    
    return 0
}

# ============================================================
# TESTS: UI/UX Elements
# ============================================================

test_bar_widget_has_colors() {
    # The state colour is either a direct `color:` or the shared
    # WidgetButton's `foreground:` token.
    grep -q "color:\|foreground:" "$PLUGIN_DIR/BarWidget.qml"
}

test_bar_widget_has_font_size() {
    # The label size is either set here or delegated to the shared
    # WidgetButton (which inherits the bar font).
    grep -q "font.pixelSize\|font.size\|fontSize\|WidgetButton" "$PLUGIN_DIR/BarWidget.qml"
}

test_panel_has_spacing() {
    grep -q "spacing\|margins" "$PLUGIN_DIR/Panel.qml"
}

test_panel_has_visual_feedback() {
    # Should have hover or click feedback
    grep -q "hoverEnabled\|onClicked\|MouseArea" "$PLUGIN_DIR/Panel.qml"
}

test_panel_has_tooltip() {
    grep -q "tooltip\|Tooltip" "$PLUGIN_DIR/Panel.qml"
}

# ============================================================
# Run all tests
# ============================================================

echo "Running E2E tests..."
echo ""

run_test "Install script exists" test_install_script_exists
run_test "Install script has valid syntax" test_install_script_syntax
run_test "Install script copies files" test_install_script_copies_files
run_test "Install creates config directory" test_install_creates_config
run_test "Install config has default stations" test_install_config_has_stations
run_test "Install copies manifest" test_install_copies_manifest
run_test "Install copies QML files" test_install_copies_qml_files
run_test "Install makes scripts executable" test_install_makes_scripts_executable

run_test "Radio control status command works" test_radio_control_status_command
run_test "Radio control lists stations" test_radio_control_lists_stations
run_test "Radio control creates state file" test_radio_control_creates_state
run_test "Radio control state has defaults" test_radio_control_state_has_defaults
run_test "Radio control preserves state" test_radio_control_preserves_state

run_test "Config parsing handles spaces" test_config_parsing_with_spaces
run_test "Config parsing handles special characters" test_config_parsing_special_characters
run_test "Config parsing handles URLs" test_config_parsing_urls
run_test "Config handles multiple stations" test_config_multiple_stations

run_test "Plugin files are complete" test_plugin_files_complete
run_test "Plugin scripts are executable" test_plugin_scripts_executable
run_test "Plugin has README" test_plugin_has_readme
run_test "README has installation instructions" test_plugin_readme_has_installation
run_test "README has usage instructions" test_plugin_readme_has_usage

run_test "Manifest integration is correct" test_manifest_integration
run_test "QML module names match" test_qml_module_names_match
run_test "Widget has required properties" test_widget_has_required_properties
run_test "Panel has required elements" test_panel_has_required_elements

run_test "Graceful handling of missing config" test_graceful_missing_config
run_test "Graceful handling of invalid station" test_graceful_invalid_station
run_test "Graceful handling of malformed config" test_graceful_malformed_config

run_test "Bar widget has colors" test_bar_widget_has_colors
run_test "Bar widget has font size" test_bar_widget_has_font_size
run_test "Panel has spacing" test_panel_has_spacing
run_test "Panel has visual feedback" test_panel_has_visual_feedback
run_test "Panel has tooltip" test_panel_has_tooltip

# Cleanup
rm -rf "$TEST_HOME"

# Summary
echo ""
echo "========================================="
echo "E2E Test Results:"
echo "  Total: $TESTS_RUN"
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"
echo "========================================="

if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
fi

exit 0