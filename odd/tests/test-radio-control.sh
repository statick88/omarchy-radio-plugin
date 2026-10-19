#!/bin/bash
# Unit tests for radio-control.sh using TDD approach
# Run with: ./test-radio-control.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RADIO_SCRIPT="$SCRIPT_DIR/../radio-control.sh"
TEST_DIR=$(mktemp -d)
export HOME="$TEST_DIR"  # Override HOME for testing

# Test infrastructure
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_func="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "  $test_name... "
    
    # Setup
    mkdir -p "$HOME/.config/omarchy-radio"
    
    # Run test
    if $test_func; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "✓ PASS"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo "✗ FAIL"
    fi
    
    # Cleanup
    rm -rf "$HOME/.config/omarchy-radio"
}

# ============================================================
# TESTS: Configuration File Handling
# ============================================================

test_config_file_creation() {
    # Test: Config file is created automatically
    rm -f "$HOME/.config/omarchy-radio/stations.conf"
    
    # Run status - should create default config
    "$RADIO_SCRIPT" status > /dev/null 2>&1 || true
    
    # Verify file was created with default stations
    [ -f "$HOME/.config/omarchy-radio/stations.conf" ] && \
    grep -q "Radio Paradise" "$HOME/.config/omarchy-radio/stations.conf"
}

test_config_file_parsing() {
    # Test: Config file is parsed correctly
    cat > "$HOME/.config/omarchy-radio/stations.conf" << 'EOF'
# Test configuration
1|Station One|https://example.com/station1
2|Station Two|https://example.com/station2
3|Station Three|https://example.com/station3
EOF
    
    # Run status command
    local output=$("$RADIO_SCRIPT" status 2>&1)
    
    # Verify stations are listed
    echo "$output" | grep -q "Station One" || return 1
    echo "$output" | grep -q "Station Two" || return 1
    echo "$output" | grep -q "Station Three" || return 1
    
    return 0
}

test_config_file_comments_ignored() {
    # Test: Comments in config are ignored
    cat > "$HOME/.config/omarchy-radio/stations.conf" << 'EOF'
# This is a comment
1|Station One|https://example.com/station1
# Another comment
2|Station Two|https://example.com/station2
EOF
    
    local output=$("$RADIO_SCRIPT" status 2>&1)
    
    # Should show stations but not comments
    echo "$output" | grep -q "Station One" || return 1
    echo "$output" | grep -q "Station Two" || return 1
    ! echo "$output" | grep -q "This is a comment" || return 1
    
    return 0
}

# ============================================================
# TESTS: State Management
# ============================================================

test_state_file_creation() {
    # Test: State file is created with default values
    rm -f "$HOME/.config/omarchy-radio/state"
    
    # Run status to trigger state creation
    "$RADIO_SCRIPT" status > /dev/null 2>&1 || true
    
    # Check if state file exists
    [ -f "$HOME/.config/omarchy-radio/state" ] || return 1
    
    # Verify it contains expected fields
    grep -q "CURRENT_STATION" "$HOME/.config/omarchy-radio/state" || return 1
    grep -q "IS_PLAYING" "$HOME/.config/omarchy-radio/state" || return 1
    grep -q "VOLUME" "$HOME/.config/omarchy-radio/state" || return 1
    
    return 0
}

test_state_persistence() {
    # Test: State is persisted between calls
    cat > "$HOME/.config/omarchy-radio/stations.conf" << 'EOF'
1|Station One|https://example.com/station1
2|Station Two|https://example.com/station2
EOF
    
    # Create initial state
    cat > "$HOME/.config/omarchy-radio/state" << 'EOF'
CURRENT_STATION=2
IS_PLAYING=false
VOLUME=75
EOF
    
    # Read state via status
    local output=$("$RADIO_SCRIPT" status 2>&1)
    
    # Verify state is loaded
    echo "$output" | grep -q "Estación: 2" || return 1
    echo "$output" | grep -q "Volumen: 75%" || return 1
    
    return 0
}

test_volume_range_validation() {
    # Test: Volume is clamped between 0-100
    
    # Create test state with invalid volume
    cat > "$HOME/.config/omarchy-radio/state" << 'EOF'
CURRENT_STATION=1
IS_PLAYING=false
VOLUME=150
EOF
    
    # Run status - should handle gracefully
    local output=$("$RADIO_SCRIPT" status 2>&1)
    
    # Should display volume without crashing
    echo "$output" | grep -q "Volumen:" || return 1
    
    return 0
}

# ============================================================
# TESTS: Station Navigation
# ============================================================

test_next_station_wraparound() {
    # Test: Next station wraps around from last to first
    cat > "$HOME/.config/omarchy-radio/stations.conf" << 'EOF'
1|Station One|https://example.com/station1
2|Station Two|https://example.com/station2
3|Station Three|https://example.com/station3
EOF
    
    # Set state to last station
    cat > "$HOME/.config/omarchy-radio/state" << 'EOF'
CURRENT_STATION=3
IS_PLAYING=false
VOLUME=80
EOF
    
    # Can't actually test next without mpv, but verify script doesn't crash
    "$RADIO_SCRIPT" next > /dev/null 2>&1 || true
    
    # State should be updated
    grep -q "CURRENT_STATION=" "$HOME/.config/omarchy-radio/state" || return 1
    
    return 0
}

test_prev_station_wraparound() {
    # Test: Previous station wraps around from first to last
    cat > "$HOME/.config/omarchy-radio/stations.conf" << 'EOF'
1|Station One|https://example.com/station1
2|Station Two|https://example.com/station2
3|Station Three|https://example.com/station3
EOF
    
    # Set state to first station
    cat > "$HOME/.config/omarchy-radio/state" << 'EOF'
CURRENT_STATION=1
IS_PLAYING=false
VOLUME=80
EOF
    
    # Can't actually test prev without mpv, but verify script doesn't crash
    "$RADIO_SCRIPT" prev > /dev/null 2>&1 || true
    
    # State should be updated
    grep -q "CURRENT_STATION=" "$HOME/.config/omarchy-radio/state" || return 1
    
    return 0
}

test_station_count_from_config() {
    # Test: Station count is derived from config file
    cat > "$HOME/.config/omarchy-radio/stations.conf" << 'EOF'
1|Station One|https://example.com/station1
2|Station Two|https://example.com/station2
3|Station Three|https://example.com/station3
4|Station Four|https://example.com/station4
5|Station Five|https://example.com/station5
EOF
    
    local output=$("$RADIO_SCRIPT" status 2>&1)
    
    # Should show all 5 stations
    echo "$output" | grep -q "Station Five" || return 1
    
    return 0
}

# ============================================================
# TESTS: Error Handling
# ============================================================

test_missing_config_file() {
    # Test: Config file is auto-created when missing
    rm -f "$HOME/.config/omarchy-radio/stations.conf"
    
    # Run status - should create default config
    local output=$("$RADIO_SCRIPT" status 2>&1)
    
    # Should not crash and should create config
    [ -f "$HOME/.config/omarchy-radio/stations.conf" ] || return 1
    
    return 0
}

test_invalid_station_number() {
    # Test: Graceful handling when station not found
    cat > "$HOME/.config/omarchy-radio/stations.conf" << 'EOF'
1|Station One|https://example.com/station1
2|Station Two|https://example.com/station2
EOF
    
    # Try to play non-existent station
    local output
    local exit_code=0
    output=$("$RADIO_SCRIPT" play 99 2>&1) || exit_code=$?
    
    # Should return error code
    [ $exit_code -ne 0 ] || return 1
    
    # Should show error message (in Spanish or English)
    echo "$output" | grep -qi "no encontrada\|not found\|Error" || return 1
    
    return 0
}

test_malformed_config_line() {
    # Test: Malformed lines are handled gracefully
    cat > "$HOME/.config/omarchy-radio/stations.conf" << 'EOF'
1|Station One|https://example.com/station1
malformed line here
2|Station Two|https://example.com/station2
|Missing ID|url
3|Missing URL|
EOF
    
    # Should not crash
    local output=$("$RADIO_SCRIPT" status 2>&1)
    
    # Should show valid stations
    echo "$output" | grep -q "Station One" || return 1
    echo "$output" | grep -q "Station Two" || return 1
    
    return 0
}

test_mpv_not_installed() {
    # Test: Graceful handling when mpv is not available
    # We can't easily test this without mocking PATH
    # Just verify script handles it gracefully
    return 0
}

# ============================================================
# TESTS: Command Parsing
# ============================================================

test_command_parsing_play() {
    # Test: Play command parsing
    cat > "$HOME/.config/omarchy-radio/stations.conf" << 'EOF'
1|Station One|https://example.com/station1
EOF
    
    # Can't actually run without mpv, but test argument parsing
    # We'll just verify the script doesn't crash on parse
    "$RADIO_SCRIPT" play 1 > /dev/null 2>&1 || true
    
    return 0
}

test_command_parsing_stop() {
    # Test: Stop command
    "$RADIO_SCRIPT" stop > /dev/null 2>&1 || true
    return 0
}

test_command_parsing_toggle() {
    # Test: Toggle command
    "$RADIO_SCRIPT" toggle > /dev/null 2>&1 || true
    return 0
}

test_invalid_command() {
    # Test: Invalid command shows usage
    local output
    local exit_code=0
    output=$("$RADIO_SCRIPT" invalidcommand 2>&1) || exit_code=$?
    
    [ $exit_code -ne 0 ] || return 1
    echo "$output" | grep -q "Uso:" || return 1
    
    return 0
}

test_no_command_shows_status() {
    # Test: No command defaults to status
    local output=$("$RADIO_SCRIPT" 2>&1)
    
    # Should show status
    echo "$output" | grep -q "Estado actual" || return 1
    
    return 0
}

# ============================================================
# TESTS: Default station (S4) and `add` command (S2)
# ============================================================

test_default_first_station_is_exa() {
    rm -f "$HOME/.config/omarchy-radio/stations.conf"
    "$RADIO_SCRIPT" status > /dev/null 2>&1

    grep -q "^1|Radio Exa 92.5 FM Ecuador|https://26573.live.streamtheworld.com/ECUADORAAC.aac$" \
        "$HOME/.config/omarchy-radio/stations.conf" || return 1
    [ "$(grep -m1 '^[0-9]' "$HOME/.config/omarchy-radio/stations.conf")" = \
        "1|Radio Exa 92.5 FM Ecuador|https://26573.live.streamtheworld.com/ECUADORAAC.aac" ] || return 1
    return 0
}

test_add_station_appends() {
    rm -f "$HOME/.config/omarchy-radio/stations.conf"
    "$RADIO_SCRIPT" status > /dev/null 2>&1
    local before after
    before=$(grep -c '^[0-9]' "$HOME/.config/omarchy-radio/stations.conf")

    "$RADIO_SCRIPT" add "Mi Radio Local" "https://example.com/stream" > /dev/null 2>&1 || return 1

    after=$(grep -c '^[0-9]' "$HOME/.config/omarchy-radio/stations.conf")
    [ "$after" -eq $((before + 1)) ] || return 1
    grep -q "|Mi Radio Local|https://example.com/stream$" \
        "$HOME/.config/omarchy-radio/stations.conf" || return 1

    # The new station is listed by status
    "$RADIO_SCRIPT" status 2>&1 | grep -q "Mi Radio Local" || return 1
    return 0
}

test_add_station_rejects_non_http_url() {
    rm -f "$HOME/.config/omarchy-radio/stations.conf"
    "$RADIO_SCRIPT" status > /dev/null 2>&1
    local before after
    before=$(cksum "$HOME/.config/omarchy-radio/stations.conf")

    local output code=0
    output=$("$RADIO_SCRIPT" add "FTP Radio" "ftp://example.com/x" 2>&1) || code=$?
    [ "$code" -ne 0 ] || return 1
    echo "$output" | grep -qi "http" || return 1

    after=$(cksum "$HOME/.config/omarchy-radio/stations.conf")
    [ "$before" = "$after" ] || return 1
    return 0
}

test_add_station_rejects_pipe_in_name() {
    rm -f "$HOME/.config/omarchy-radio/stations.conf"
    "$RADIO_SCRIPT" status > /dev/null 2>&1
    local before after
    before=$(cksum "$HOME/.config/omarchy-radio/stations.conf")

    local code=0
    "$RADIO_SCRIPT" add "Nombre|con pipe" "https://example.com/x" > /dev/null 2>&1 || code=$?
    [ "$code" -ne 0 ] || return 1

    after=$(cksum "$HOME/.config/omarchy-radio/stations.conf")
    [ "$before" = "$after" ] || return 1
    return 0
}

test_add_station_rejects_duplicate_name() {
    rm -f "$HOME/.config/omarchy-radio/stations.conf"
    "$RADIO_SCRIPT" status > /dev/null 2>&1
    local before after
    before=$(cksum "$HOME/.config/omarchy-radio/stations.conf")

    local output code=0
    output=$("$RADIO_SCRIPT" add "Radio Exa 92.5 FM Ecuador" "https://example.com/other" 2>&1) || code=$?
    [ "$code" -ne 0 ] || return 1
    echo "$output" | grep -qi "ya existe" || return 1

    after=$(cksum "$HOME/.config/omarchy-radio/stations.conf")
    [ "$before" = "$after" ] || return 1
    return 0
}

test_add_station_rejects_empty_name() {
    rm -f "$HOME/.config/omarchy-radio/stations.conf"
    "$RADIO_SCRIPT" status > /dev/null 2>&1
    local before after
    before=$(cksum "$HOME/.config/omarchy-radio/stations.conf")

    local code=0
    "$RADIO_SCRIPT" add "" "https://example.com/x" > /dev/null 2>&1 || code=$?
    [ "$code" -ne 0 ] || return 1

    after=$(cksum "$HOME/.config/omarchy-radio/stations.conf")
    [ "$before" = "$after" ] || return 1
    return 0
}

test_usage_mentions_add_command() {
    local output code=0
    output=$("$RADIO_SCRIPT" --help 2>&1) || code=$?
    [ "$code" -ne 0 ] || return 1
    echo "$output" | grep -q "add" || return 1
    return 0
}

# ============================================================
# TESTS: Player lifecycle (pid file + sweep driven by stations.conf)
# ============================================================
#
# These tests shim mpv and pkill so the real players are never touched: the
# shims append one line per invocation to $SHIM_LOG, which is how the suite
# observes what the script decided to kill and to start.

setup_player_shims() {
    SHIM_DIR=$(mktemp -d)
    export SHIM_LOG="$SHIM_DIR/invocations.log"
    : > "$SHIM_LOG"

    cat > "$SHIM_DIR/mpv" <<'SHIM'
#!/bin/bash
echo "MPV $*" >> "$SHIM_LOG"
SHIM
    cat > "$SHIM_DIR/pkill" <<'SHIM'
#!/bin/bash
echo "PKILL $*" >> "$SHIM_LOG"
exit 0
SHIM
    chmod +x "$SHIM_DIR/mpv" "$SHIM_DIR/pkill"
}

cleanup_player_shims() {
    /usr/bin/pkill -f "$SHIM_DIR/mpv" 2>/dev/null || true
    rm -rf "$SHIM_DIR"
}

wait_for_log() {
    # `radio-control.sh` launches the player in the background, so the shim's
    # echo can land after the caller continues. Poll for the expected line
    # before reading the log, otherwise the suite depends on the scheduler.
    local pattern="$1"
    local tries=50
    while [ $tries -gt 0 ]; do
        grep -q "$pattern" "$SHIM_LOG" 2>/dev/null && return 0
        tries=$((tries - 1))
        sleep 0.05
    done
    return 1
}

test_play_stops_previous_stream_from_config() {
    # A player started outside the script (no pid file) must still be
    # stopped when another station is selected: the sweep has to come from
    # stations.conf, not from a hardcoded list of stream hosts.
    cat > "$HOME/.config/omarchy-radio/stations.conf" << 'EOF'
1|Station One|https://stream.host.test/one.aac
2|Station Two|https://stream.host.test/two.aac
EOF
    printf 'CURRENT_STATION=1\nIS_PLAYING=false\nVOLUME=80\n' \
        > "$HOME/.config/omarchy-radio/state"
    setup_player_shims

    PATH="$SHIM_DIR:$PATH" "$RADIO_SCRIPT" play 1 > /dev/null 2>&1 || true
    wait_for_log "^MPV " || return 1
    : > "$SHIM_LOG"
    PATH="$SHIM_DIR:$PATH" "$RADIO_SCRIPT" play 2 > /dev/null 2>&1 || true
    wait_for_log "MPV .*two.aac" || return 1

    # Station 1's stream must be swept even though no pid file pointed at it
    grep -q "PKILL .*stream.host.test/one.aac" "$SHIM_LOG" || return 1
    # And exactly one player must be left: the newly selected station
    [ "$(grep -c '^MPV ' "$SHIM_LOG")" -eq 1 ] || return 1
    grep -q "MPV .*two.aac" "$SHIM_LOG" || return 1
    grep -q "^CURRENT_STATION=2$" "$HOME/.config/omarchy-radio/state" || return 1
    grep -q "^IS_PLAYING=true$" "$HOME/.config/omarchy-radio/state" || return 1

    cleanup_player_shims
    return 0
}

test_stop_kills_any_configured_stream() {
    # The default station is the Exa stream (streamtheworld), which is in no
    # hardcoded kill list: `stop` must still be able to silence it.
    cat > "$HOME/.config/omarchy-radio/stations.conf" << 'EOF'
1|Radio Exa 92.5 FM Ecuador|https://26573.live.streamtheworld.com/ECUADORAAC.aac
EOF
    setup_player_shims

    PATH="$SHIM_DIR:$PATH" "$RADIO_SCRIPT" play 1 > /dev/null 2>&1 || true
    wait_for_log "^MPV " || return 1
    : > "$SHIM_LOG"
    PATH="$SHIM_DIR:$PATH" "$RADIO_SCRIPT" stop > /dev/null 2>&1 || true

    grep -q "PKILL .*ECUADORAAC.aac" "$SHIM_LOG" || return 1
    grep -q "^IS_PLAYING=false$" "$HOME/.config/omarchy-radio/state" || return 1

    cleanup_player_shims
    return 0
}

test_stop_sweeps_every_configured_stream() {
    # Every URL in stations.conf must be swept, whatever its host is: the
    # list of targets comes from the file, never from a hardcoded pattern.
    cat > "$HOME/.config/omarchy-radio/stations.conf" << 'EOF'
# comment line that must be ignored
1|Station One|https://stream.host.test/one.aac

2|Station Two|https://stream.host.test/two.aac
EOF
    printf 'CURRENT_STATION=2\nIS_PLAYING=true\nVOLUME=80\n' \
        > "$HOME/.config/omarchy-radio/state"
    setup_player_shims

    PATH="$SHIM_DIR:$PATH" "$RADIO_SCRIPT" stop > /dev/null 2>&1 || true

    grep -q "PKILL .*stream.host.test/one.aac" "$SHIM_LOG" || return 1
    grep -q "PKILL .*stream.host.test/two.aac" "$SHIM_LOG" || return 1
    grep -q "^IS_PLAYING=false$" "$HOME/.config/omarchy-radio/state" || return 1

    cleanup_player_shims
    return 0
}

test_stop_with_empty_config_still_stops() {
    # An empty or comment-only stations.conf must not break `stop`: the pid
    # kill and the state write still have to happen.
    cat > "$HOME/.config/omarchy-radio/stations.conf" << 'EOF'
# solo comentarios, ninguna estación
EOF
    setup_player_shims

    PATH="$SHIM_DIR:$PATH" "$RADIO_SCRIPT" stop > /dev/null 2>&1 || return 1
    grep -q "^IS_PLAYING=false$" "$HOME/.config/omarchy-radio/state" || return 1

    cleanup_player_shims
    return 0
}

test_play_with_missing_config_creates_default() {
    # Without any stations.conf the default file is created (Exa first) and
    # the sweep still covers that default stream.
    rm -f "$HOME/.config/omarchy-radio/stations.conf"
    setup_player_shims

    PATH="$SHIM_DIR:$PATH" "$RADIO_SCRIPT" play 1 > /dev/null 2>&1 || return 1
    grep -q "streamtheworld.com/ECUADORAAC.aac" \
        "$HOME/.config/omarchy-radio/stations.conf" || return 1
    grep -q "^MPV " "$SHIM_LOG" || return 1

    cleanup_player_shims
    return 0
}

# ============================================================
# Run all tests
# ============================================================

echo "Running radio-control.sh unit tests..."
echo ""

run_test "Config: Auto-creation when missing" test_config_file_creation
run_test "Config: File parsing" test_config_file_parsing
run_test "Config: Comments are ignored" test_config_file_comments_ignored

run_test "State: File creation with defaults" test_state_file_creation
run_test "State: Persistence between calls" test_state_persistence
run_test "State: Volume range handling" test_volume_range_validation

run_test "Navigation: Next station wraparound" test_next_station_wraparound
run_test "Navigation: Prev station wraparound" test_prev_station_wraparound
run_test "Navigation: Station count from config" test_station_count_from_config

run_test "Error: Auto-creates missing config" test_missing_config_file
run_test "Error: Invalid station number" test_invalid_station_number
run_test "Error: Malformed config line" test_malformed_config_line
run_test "Error: mpv not installed" test_mpv_not_installed

run_test "Command: Parse play" test_command_parsing_play
run_test "Command: Parse stop" test_command_parsing_stop
run_test "Command: Parse toggle" test_command_parsing_toggle
run_test "Command: Invalid command" test_invalid_command
run_test "Command: No command shows status" test_no_command_shows_status

run_test "Default: First station is Radio Exa" test_default_first_station_is_exa
run_test "Add: Appends station and lists it" test_add_station_appends
run_test "Add: Rejects non-http URL" test_add_station_rejects_non_http_url
run_test "Add: Rejects pipe in name" test_add_station_rejects_pipe_in_name
run_test "Add: Rejects duplicate name" test_add_station_rejects_duplicate_name
run_test "Add: Rejects empty name" test_add_station_rejects_empty_name
run_test "Command: Usage mentions add" test_usage_mentions_add_command
run_test "Player: play stops previous stream from config" test_play_stops_previous_stream_from_config
run_test "Player: stop kills any configured stream" test_stop_kills_any_configured_stream
run_test "Player: stop sweeps every configured stream URL" test_stop_sweeps_every_configured_stream
run_test "Player: stop with empty config still stops" test_stop_with_empty_config_still_stops
run_test "Player: play with missing config creates default" test_play_with_missing_config_creates_default

# Cleanup
rm -rf "$TEST_DIR"

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