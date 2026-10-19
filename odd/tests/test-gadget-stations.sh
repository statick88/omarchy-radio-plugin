#!/bin/bash
# Tests for the stations imported from the SketchyBar radio gadget (mac).
# Run with: ./test-gadget-stations.sh
# Optional live stream checks: LIVE_STREAMS=1 ./test-gadget-stations.sh
#
# Safety: this suite never touches real playback. `mpv` and `pkill` are
# replaced by PATH shims, so no radio stream is started and no process on
# the machine is killed (radio-control.sh stop/next/prev call `pkill -f`
# with global scope).

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RADIO_SCRIPT="$SCRIPT_DIR/../radio-control.sh"
FIXTURE="$SCRIPT_DIR/fixtures/gadget-stations.conf"
CONFIG_DIR_NAME=".config/omarchy-radio"

TEST_DIR=$(mktemp -d)
export HOME="$TEST_DIR" # Override HOME for testing

SHIM_DIR="$TEST_DIR/bin"
MPV_LOG="$TEST_DIR/mpv.log"
PKILL_LOG="$TEST_DIR/pkill.log"
mkdir -p "$SHIM_DIR"
: > "$MPV_LOG"
: > "$PKILL_LOG"

cat > "$SHIM_DIR/mpv" << 'EOF'
#!/bin/bash
echo "$@" >> "${MPV_LOG}"
exit 0
EOF

cat > "$SHIM_DIR/pkill" << 'EOF'
#!/bin/bash
echo "pkill $*" >> "${PKILL_LOG}"
exit 0
EOF

chmod +x "$SHIM_DIR/mpv" "$SHIM_DIR/pkill"
export PATH="$SHIM_DIR:$PATH"
export MPV_LOG PKILL_LOG

# Test infrastructure
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

run_test() {
    local test_name="$1"
    local test_func="$2"

    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "  $test_name... "

    mkdir -p "$HOME/$CONFIG_DIR_NAME"

    if $test_func; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "✓ PASS"
    else
        local code=$?
        if [ "$code" -eq 77 ]; then
            TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
            echo "⊘ SKIP (opt-in)"
        else
            TESTS_FAILED=$((TESTS_FAILED + 1))
            echo "✗ FAIL"
        fi
    fi

    rm -rf "$HOME/$CONFIG_DIR_NAME"
}

reset_logs() {
    : > "$MPV_LOG"
    : > "$PKILL_LOG"
}

station_count() {
    grep -c '^[0-9]' "$FIXTURE"
}

current_station() {
    grep '^CURRENT_STATION=' "$HOME/$CONFIG_DIR_NAME/state" 2>/dev/null | cut -d'=' -f2
}

# ============================================================
# TESTS: Fixture provenance and format
# ============================================================

test_fixture_exists() {
    [ -f "$FIXTURE" ]
}

test_fixture_has_three_stations() {
    [ "$(station_count)" -eq 3 ]
}

test_fixture_ids_are_sequential() {
    local ids
    ids=$(grep '^[0-9]' "$FIXTURE" | cut -d'|' -f1 | tr '\n' ' ')
    [ "$ids" = "1 2 3 " ]
}

test_fixture_urls_are_https() {
    local bad
    bad=$(grep '^[0-9]' "$FIXTURE" | awk -F'|' '$3 !~ /^https:\/\// { print $3 }')
    [ -z "$bad" ]
}

test_fixture_has_gadget_names() {
    grep -q "Radio Boquerón Catamayo Loja Ecuador" "$FIXTURE" || return 1
    grep -q "Radio Exa Ecuador" "$FIXTURE" || return 1
    grep -q "Radio Ritmo Romántica Perú" "$FIXTURE" || return 1
    return 0
}

test_fixture_urls_match_gadget() {
    grep -q "stream.hospedandosites.com.br:8038/stream" "$FIXTURE" || return 1
    grep -q "26573.live.streamtheworld.com/ECUADORAAC.aac" "$FIXTURE" || return 1
    grep -q "mdstrm.com/audio/6839e2376607bdf6b2fcde27/live.m3u8" "$FIXTURE" || return 1
    return 0
}

# ============================================================
# TESTS: radio-control.sh behaviour with the gadget stations
# ============================================================

test_status_lists_gadget_stations() {
    cp "$FIXTURE" "$HOME/$CONFIG_DIR_NAME/stations.conf"
    local output
    output=$("$RADIO_SCRIPT" status 2>&1)

    echo "$output" | grep -q "Radio Boquerón Catamayo Loja Ecuador" || return 1
    echo "$output" | grep -q "Radio Exa Ecuador" || return 1
    echo "$output" | grep -q "Radio Ritmo Romántica Perú" || return 1
    return 0
}

test_status_marks_first_station_active() {
    cp "$FIXTURE" "$HOME/$CONFIG_DIR_NAME/stations.conf"
    local output
    output=$("$RADIO_SCRIPT" status 2>&1)

    echo "$output" | grep -q "▶ 1. Radio Boquerón" || return 1
    return 0
}

test_play_uses_gadget_stream() {
    reset_logs
    cp "$FIXTURE" "$HOME/$CONFIG_DIR_NAME/stations.conf"

    "$RADIO_SCRIPT" play 2 > /dev/null 2>&1
    sleep 0.3

    grep -q "ECUADORAAC.aac" "$MPV_LOG" || return 1
    [ "$(current_station)" = "2" ] || return 1
    grep -q "^IS_PLAYING=true" "$HOME/$CONFIG_DIR_NAME/state" || return 1
    return 0
}

test_next_cycles_through_gadget_stations() {
    reset_logs
    cp "$FIXTURE" "$HOME/$CONFIG_DIR_NAME/stations.conf"
    "$RADIO_SCRIPT" status > /dev/null 2>&1 # creates state at station 1

    "$RADIO_SCRIPT" next > /dev/null 2>&1
    [ "$(current_station)" = "2" ] || return 1

    "$RADIO_SCRIPT" next > /dev/null 2>&1
    [ "$(current_station)" = "3" ] || return 1

    "$RADIO_SCRIPT" next > /dev/null 2>&1
    [ "$(current_station)" = "1" ] || return 1 # wraparound

    sleep 0.3
    # Every gadget stream must have been handed to the player exactly once
    [ "$(grep -c "stream.hospedandosites.com.br" "$MPV_LOG")" -eq 1 ] || return 1
    [ "$(grep -c "ECUADORAAC.aac" "$MPV_LOG")" -eq 1 ] || return 1
    [ "$(grep -c "mdstrm.com" "$MPV_LOG")" -eq 1 ] || return 1
    return 0
}

test_prev_wraps_from_first_station() {
    reset_logs
    cp "$FIXTURE" "$HOME/$CONFIG_DIR_NAME/stations.conf"
    "$RADIO_SCRIPT" status > /dev/null 2>&1

    "$RADIO_SCRIPT" prev > /dev/null 2>&1
    [ "$(current_station)" = "3" ] || return 1

    "$RADIO_SCRIPT" prev > /dev/null 2>&1
    [ "$(current_station)" = "2" ] || return 1
    return 0
}

test_stop_never_reaches_real_pkill() {
    reset_logs
    cp "$FIXTURE" "$HOME/$CONFIG_DIR_NAME/stations.conf"
    "$RADIO_SCRIPT" play 1 > /dev/null 2>&1
    sleep 0.3
    "$RADIO_SCRIPT" stop > /dev/null 2>&1

    # The pkill shim must have been the one invoked (no global process kill)
    grep -q "^pkill" "$PKILL_LOG" || return 1
    grep -q "^IS_PLAYING=false" "$HOME/$CONFIG_DIR_NAME/state" || return 1
    return 0
}

test_station_not_in_config_is_rejected() {
    cp "$FIXTURE" "$HOME/$CONFIG_DIR_NAME/stations.conf"
    local output code=0
    output=$("$RADIO_SCRIPT" play 42 2>&1) || code=$?

    [ "$code" -eq 1 ] || return 1
    echo "$output" | grep -q "Estación 42 no encontrada" || return 1
    return 0
}

test_live_streams_reachable() {
    if [ "${LIVE_STREAMS:-0}" != "1" ]; then
        return 77 # skipped unless explicitly requested
    fi

    local url code
    while IFS='|' read -r _id _name url; do
        case "$url" in
            http*) ;;
            *) continue ;;
        esac
        code=$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 8 -r 0-2048 \
            -A "Mozilla/5.0" "$url" || true)
        case "$code" in
            200|206|301|302|303|307|308) ;;
            *) echo " (stream $url -> $code)" >&2; return 1 ;;
        esac
    done < "$FIXTURE"
    return 0
}

# ============================================================
# Run all tests
# ============================================================

echo ""
echo "Running SketchyBar gadget station tests..."
echo ""

run_test "Fixture exists" test_fixture_exists
run_test "Fixture has 3 stations" test_fixture_has_three_stations
run_test "Fixture ids are sequential 1..3" test_fixture_ids_are_sequential
run_test "Fixture URLs use https" test_fixture_urls_are_https
run_test "Fixture keeps gadget station names" test_fixture_has_gadget_names
run_test "Fixture keeps gadget stream URLs" test_fixture_urls_match_gadget

run_test "Status lists gadget stations" test_status_lists_gadget_stations
run_test "Status marks first station active" test_status_marks_first_station_active
run_test "Play uses gadget stream" test_play_uses_gadget_stream
run_test "Next cycles through gadget stations" test_next_cycles_through_gadget_stations
run_test "Prev wraps from first station" test_prev_wraps_from_first_station
run_test "Stop never reaches real pkill" test_stop_never_reaches_real_pkill
run_test "Unknown station is rejected" test_station_not_in_config_is_rejected
run_test "Live streams reachable" test_live_streams_reachable

# Cleanup
rm -rf "$TEST_DIR"

echo ""
echo "========================================="
echo "Gadget Station Test Results:"
echo "  Total:    $TESTS_RUN"
echo "  Passed:   $TESTS_PASSED"
echo "  Failed:   $TESTS_FAILED"
if [ "$TESTS_SKIPPED" -gt 0 ]; then
    echo "  Skipped:  $TESTS_SKIPPED (run LIVE_STREAMS=1 for live checks)"
fi
echo "========================================="

[ "$TESTS_FAILED" -eq 0 ]
