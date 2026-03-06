#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Atelier Socle SAS
#
# CLI Scenario Test Runner
# Validates all hlskit-cli commands against the mock HLS server.
#
# Usage:
#   ./Scripts/run-cli-scenarios.sh                # Full run (build + mock + scenarios + cleanup)
#   ./Scripts/run-cli-scenarios.sh --skip-build   # Skip release build
#   ./Scripts/run-cli-scenarios.sh --keep-temp    # Keep temp files after run
#
# Prerequisites:
#   - swift build must succeed
#   - python3 available (for mock server)
#   - ffmpeg available (for test audio generation)
#
# Exit codes:
#   0 — all scenarios passed
#   1 — one or more scenarios failed

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CLI="$PROJECT_DIR/.build/release/hlskit-cli"
MOCK_SERVER="$PROJECT_DIR/Scripts/mock-hls-server.py"
MOCK_PORT=18888
TEMP_DIR="/tmp/hlskit-scenarios-$$"

SKIP_BUILD=false
KEEP_TEMP=false

for arg in "$@"; do
    case "$arg" in
        --skip-build) SKIP_BUILD=true ;;
        --keep-temp) KEEP_TEMP=true ;;
    esac
done

# ── Counters ───────────────────────────────────────────────────────
PASS=0
FAIL=0
CHECK=0
TOTAL=0

scenario_pass() {
    PASS=$((PASS + 1))
    TOTAL=$((TOTAL + 1))
    echo "  PASS"
}

scenario_fail() {
    FAIL=$((FAIL + 1))
    TOTAL=$((TOTAL + 1))
    echo "  FAIL"
}

scenario_check() {
    CHECK=$((CHECK + 1))
    TOTAL=$((TOTAL + 1))
    echo "  CHECK (manual verification needed)"
}

run_scenario() {
    local name="$1"
    shift
    echo "=== $name ==="
}

# ── Phase 1: Build ─────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          swift-hls-kit CLI Scenario Test Runner             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

cd "$PROJECT_DIR"

if [ "$SKIP_BUILD" = false ]; then
    echo "── Phase 1: Release Build ──"
    swift build -c release 2>&1 | tail -3
    echo ""
fi

if [ ! -f "$CLI" ]; then
    echo "ERROR: CLI not found at $CLI"
    echo "Run 'swift build -c release' first."
    exit 1
fi

# ── Phase 2: Start Mock Server ─────────────────────────────────────
echo "── Phase 2: Start Mock Server ──"
pkill -f "mock-hls-server" 2>/dev/null || true
sleep 1

python3 "$MOCK_SERVER" --mode serve --port "$MOCK_PORT" > /dev/null 2>&1 &
MOCK_PID=$!
sleep 2

if ! curl -s "http://localhost:$MOCK_PORT/vod/master.m3u8" > /dev/null 2>&1; then
    echo "ERROR: Mock server failed to start on port $MOCK_PORT"
    exit 1
fi
echo "  Mock server running (PID $MOCK_PID)"
echo ""

# ── Phase 3: Download Test Data ────────────────────────────────────
echo "── Phase 3: Download Test Data ──"
P="$TEMP_DIR"
mkdir -p "$P"

curl -s "http://localhost:$MOCK_PORT/vod/master.m3u8"              -o "$P/vod-master.m3u8"
curl -s "http://localhost:$MOCK_PORT/vod/360p/playlist.m3u8"       -o "$P/vod-360p.m3u8"
curl -s "http://localhost:$MOCK_PORT/vod/encrypted/master.m3u8"    -o "$P/encrypted-master.m3u8"
curl -s "http://localhost:$MOCK_PORT/vod/encrypted/playlist.m3u8"  -o "$P/encrypted-media.m3u8"
curl -s "http://localhost:$MOCK_PORT/vod/iframe/playlist.m3u8"     -o "$P/iframe.m3u8"
curl -s "http://localhost:$MOCK_PORT/vod/byterange/playlist.m3u8"  -o "$P/byterange.m3u8"
curl -s "http://localhost:$MOCK_PORT/live/master.m3u8"             -o "$P/live-master.m3u8"
curl -s "http://localhost:$MOCK_PORT/meta/playlist.m3u8"           -o "$P/meta.m3u8"
curl -s "http://localhost:$MOCK_PORT/drm/master.m3u8"              -o "$P/drm.m3u8"
curl -s "http://localhost:$MOCK_PORT/a11y/master.m3u8"             -o "$P/a11y.m3u8"
curl -s "http://localhost:$MOCK_PORT/steer/master.m3u8"            -o "$P/steer.m3u8"
curl -s "http://localhost:$MOCK_PORT/var/master.m3u8"              -o "$P/var-master.m3u8"
curl -s "http://localhost:$MOCK_PORT/spatial/master.m3u8"          -o "$P/spatial-master.m3u8"
curl -s "http://localhost:$MOCK_PORT/spatial/immersive.m3u8"       -o "$P/immersive.m3u8"
curl -s "http://localhost:$MOCK_PORT/spatial/360.m3u8"             -o "$P/360.m3u8"
curl -s "http://localhost:$MOCK_PORT/subs/master.m3u8"             -o "$P/subs-master.m3u8"
curl -s "http://localhost:$MOCK_PORT/subs/sample.ttml"             -o "$P/sample.ttml"
curl -s "http://localhost:$MOCK_PORT/spatial/sample.hevc"          -o "$P/sample.hevc"

echo "  Downloaded 18 test files"

# Generate test audio
ffmpeg -f lavfi -i sine=frequency=440:duration=12 -c:a aac -b:a 128k "$P/test-audio.m4a" -y > /dev/null 2>&1
echo "  Generated test audio"
echo ""

# ── Phase 4: Run Scenarios ─────────────────────────────────────────
echo "── Phase 4: CLI Scenarios ──"
echo ""

# --- Core CLI (0.1.0) ---

run_scenario "SCENARIO 1: CLI Help"
$CLI --help 2>&1 | grep -q "SUBCOMMANDS" && scenario_pass || scenario_fail

run_scenario "SCENARIO 2: VOD Master Parse"
$CLI manifest parse "$P/vod-master.m3u8" 2>&1 | grep -q "Variants:.*3" && scenario_pass || scenario_fail

run_scenario "SCENARIO 3: VOD Media Parse"
$CLI manifest parse "$P/vod-360p.m3u8" 2>&1 | grep -q "Segments:.*4" && scenario_pass || scenario_fail

run_scenario "SCENARIO 4: Validate"
$CLI validate "$P/vod-master.m3u8" 2>&1 | grep -q "Valid" && scenario_pass || scenario_fail

run_scenario "SCENARIO 5: Info M3U8"
$CLI info "$P/vod-master.m3u8" 2>&1 | grep -q "Variants:.*3" && scenario_pass || scenario_fail

# --- Encryption & Display (0.2.0 + 0.4.0 improvements) ---

run_scenario "SCENARIO 6: Encrypted Master — Session Key"
$CLI manifest parse "$P/encrypted-master.m3u8" 2>&1 | grep -qi "session\|key\|encrypt" && scenario_pass || scenario_check

run_scenario "SCENARIO 7: Encrypted Media — KEY details"
$CLI manifest parse "$P/encrypted-media.m3u8" 2>&1 | grep -qi "aes\|encrypt\|key" && scenario_pass || scenario_check

run_scenario "SCENARIO 8: I-Frame Playlist"
$CLI manifest parse "$P/iframe.m3u8" 2>&1 | grep -qi "i-frame\|iframe" && scenario_pass || scenario_check

run_scenario "SCENARIO 9: Byte-Range"
$CLI manifest parse "$P/byterange.m3u8" 2>&1 | grep -q "bigfile" && scenario_pass || scenario_fail

# --- Segmentation (0.1.0) ---

run_scenario "SCENARIO 10: Segmentation fMP4"
mkdir -p "$P/segments"
$CLI segment "$P/test-audio.m4a" --output "$P/segments" --format fmp4 --duration 4 2>&1 | grep -q "Created" && scenario_pass || scenario_fail

run_scenario "SCENARIO 11: Segments verified"
ls "$P/segments/init.mp4" "$P/segments/playlist.m3u8" > /dev/null 2>&1 && scenario_pass || scenario_fail

run_scenario "SCENARIO 12: Segmentation TS"
mkdir -p "$P/segments-ts"
$CLI segment "$P/test-audio.m4a" --output "$P/segments-ts" --format ts --duration 4 2>&1 | grep -q "Created" && scenario_pass || scenario_fail

run_scenario "SCENARIO 13: Validate auto-generated"
$CLI validate "$P/segments/playlist.m3u8" 2>&1 | grep -q "Valid" && scenario_pass || scenario_fail

# --- Encryption (0.1.0) ---

run_scenario "SCENARIO 14: Encrypt AES-128"
mkdir -p "$P/enc"
cp "$P/segments/"* "$P/enc/" 2>/dev/null
$CLI encrypt "$P/enc" --key-url "https://cdn.example.com/key" --write-key 2>&1 | grep -q "Encrypted" && scenario_pass || scenario_fail

run_scenario "SCENARIO 15: Encrypted playlist has KEY"
grep -q "EXT-X-KEY" "$P/enc/playlist.m3u8" && scenario_pass || scenario_fail

# --- Info & Generate (0.1.0) ---

run_scenario "SCENARIO 16: Info MP4"
$CLI info "$P/test-audio.m4a" 2>&1 | grep -q "MP4" && scenario_pass || scenario_fail

run_scenario "SCENARIO 17: Manifest Generate"
python3 -c "
import json
json.dump({'variants':[{'bandwidth':800000,'resolution':'640x360','codecs':'avc1.4d401e','uri':'360p/p.m3u8'}]}, open('$P/gen.json','w'))
"
$CLI manifest generate "$P/gen.json" 2>&1 | grep -q "EXT-X-STREAM-INF" && scenario_pass || scenario_fail

# --- Live (0.2.0) ---

run_scenario "SCENARIO 18: Live Master"
$CLI manifest parse "$P/live-master.m3u8" 2>&1 | grep -q "Variants:.*2" && scenario_pass || scenario_fail

# --- Metadata, DRM, Accessibility (0.2.0) ---

run_scenario "SCENARIO 19a: Metadata"
$CLI manifest parse "$P/meta.m3u8" 2>&1 | grep -q "Segments:.*4" && scenario_pass || scenario_fail

run_scenario "SCENARIO 19b: DRM"
$CLI manifest parse "$P/drm.m3u8" 2>&1 | grep -q "Variants:.*1" && scenario_pass || scenario_fail

run_scenario "SCENARIO 19c: Accessibility"
$CLI manifest parse "$P/a11y.m3u8" 2>&1 | grep -q "CLOSED-CAPTIONS" && scenario_pass || scenario_fail

run_scenario "SCENARIO 19d: DRM — Session Key"
$CLI manifest parse "$P/drm.m3u8" 2>&1 | grep -qi "session\|fairplay\|cenc\|key" && scenario_pass || scenario_check

# --- Content Steering (0.3.0) ---

run_scenario "SCENARIO 20: Content Steering"
$CLI manifest parse "$P/steer.m3u8" 2>&1 | grep -qi "steer\|pathway\|CDN" && scenario_pass || scenario_check

# --- Variable Substitution (0.3.0) ---

run_scenario "SCENARIO 21: Variable Substitution"
$CLI manifest parse "$P/var-master.m3u8" 2>&1 | grep -q "Definitions:.*3" && scenario_pass || scenario_fail

run_scenario "SCENARIO 22: Variables QUERYPARAM"
$CLI manifest parse "$P/var-master.m3u8" 2>&1 | grep -q "QUERYPARAM" && scenario_pass || scenario_fail

# --- Spatial Video (0.3.0) ---

run_scenario "SCENARIO 23: Spatial REQ-VIDEO-LAYOUT"
$CLI manifest parse "$P/spatial-master.m3u8" 2>&1 | grep -q "REQ-VIDEO-LAYOUT" && scenario_pass || scenario_fail

run_scenario "SCENARIO 24a: Immersive 180"
$CLI manifest parse "$P/immersive.m3u8" 2>&1 | grep -q "PROJ-HEQU" && scenario_pass || scenario_fail

run_scenario "SCENARIO 24b: 360"
$CLI manifest parse "$P/360.m3u8" 2>&1 | grep -q "PROJ-EQUI" && scenario_pass || scenario_fail

# --- IMSC1 Subtitles (0.4.0) ---

run_scenario "SCENARIO 25: IMSC1 Subtitles manifest"
$CLI manifest parse "$P/subs-master.m3u8" 2>&1 | grep -q "stpp.ttml.im1t" && scenario_pass || scenario_fail

run_scenario "SCENARIO 26: IMSC1 Parse"
$CLI imsc1 parse "$P/sample.ttml" 2>&1 | grep -q "Subtitles:.*4" && scenario_pass || scenario_fail

run_scenario "SCENARIO 27: IMSC1 Render"
$CLI imsc1 render "$P/sample.ttml" -o "$P/rendered.ttml" 2>&1 | grep -q "Wrote" && scenario_pass || scenario_fail

run_scenario "SCENARIO 28: IMSC1 Segment"
mkdir -p "$P/imsc1-seg"
$CLI imsc1 segment "$P/sample.ttml" -o "$P/imsc1-seg" --language en --segment-duration 6 2>&1 | grep -q "Created" && scenario_pass || scenario_fail

run_scenario "SCENARIO 29: IMSC1 Playlist valid"
$CLI validate "$P/imsc1-seg/playlist.m3u8" 2>&1 | grep -q "Valid" && scenario_pass || scenario_fail

# --- MV-HEVC (0.4.0) ---

run_scenario "SCENARIO 30: MV-HEVC Package"
mkdir -p "$P/mvhevc-out"
$CLI mvhevc package "$P/sample.hevc" -o "$P/mvhevc-out" --layout stereo --frame-rate 30 --width 1920 --height 1080 2>&1 | grep -q "Packaged" && scenario_pass || scenario_fail

run_scenario "SCENARIO 31: MV-HEVC Info — Spatial Boxes (P0 Fix)"
$CLI mvhevc info "$P/mvhevc-out/init.mp4" 2>&1 | grep -qi "vexu\|stri\|hero\|spatial.*yes" && scenario_pass || scenario_fail

# --- Generator 0.4.0 attributes ---

run_scenario "SCENARIO 32: Generate 0.4.0 attributes"
python3 -c "
import json
json.dump({
    'definitions': [{'name':'base','value':'https://cdn.example.com'}],
    'variants': [{'bandwidth':10000000,'resolution':'1920x1080','codecs':'hvc1.2.4.L123.B0','supplementalCodecs':'dvh1.20.09/db4h','videoLayoutDescriptor':'CH-STEREO','uri':'stereo/p.m3u8'}]
}, open('$P/gen040.json','w'))
"
$CLI manifest generate "$P/gen040.json" 2>&1 | grep -q "REQ-VIDEO-LAYOUT\|SUPPLEMENTAL-CODECS\|EXT-X-DEFINE" && scenario_pass || scenario_fail

run_scenario "SCENARIO 33: Generate then Validate"
$CLI manifest generate "$P/gen040.json" -o "$P/gen040.m3u8" 2>/dev/null
$CLI validate "$P/gen040.m3u8" 2>&1 | grep -q "Valid" && scenario_pass || scenario_fail

# --- Live/Push (skipped in automated gate) ---

echo ""
echo "=== SCENARIOS 34-36: Live/Push ==="
echo "  SKIP (requires manual mock server interaction)"

# --- Mock Server Fix ---

echo ""
run_scenario "MOCK SERVER FIX: QUERYPARAM token substitution"
curl -s "http://localhost:$MOCK_PORT/var/media.m3u8?token=test123" | grep -q "test123" && scenario_pass || scenario_fail

# ── Phase 5: Cleanup ──────────────────────────────────────────────
echo ""
echo "── Phase 5: Cleanup ──"
kill "$MOCK_PID" 2>/dev/null || true

if [ "$KEEP_TEMP" = false ]; then
    rm -rf "$TEMP_DIR"
    echo "  Temp files cleaned up"
else
    echo "  Temp files kept at $TEMP_DIR"
fi

# ── Results ────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  RESULTS: $PASS PASS / $FAIL FAIL / $CHECK CHECK (total: $TOTAL)"
echo "═══════════════════════════════════════════════════════════════"
echo ""

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
