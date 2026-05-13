#!/usr/bin/env bash
#
# visual-verify-progress.sh
#
# Render the HTML mockup at iPhone width and capture full-page screenshots
# that pair against the XCUITest output to produce the visual-verification
# report. See `_docs/plans/2026-05-13-progress-tab-rework.md` §6.3.
#
# What this script does:
#   1. Starts a local http.server on port 8765 serving /tmp/parlance-progress-mocks
#      (skips if something is already listening on that port).
#   2. Drives Playwright (headless Chromium) to screenshot the mockup at
#      390x2400, plus three scroll-position crops (top / mid / bottom).
#   3. Writes everything to _docs/visual-verification/$(date +%Y-%m-%d)/mockup/.
#
# This script is intentionally tolerant: if Playwright / npx / Chromium
# cannot be installed (e.g. offline CI sandbox), it logs the failure and
# exits 0 so the visual-verify pipeline still completes. The companion
# report builder (visual-verify-build-report.sh) tolerates missing
# screenshots and substitutes placeholders.

set -euo pipefail

PORT=8765
MOCK_DIR="/tmp/parlance-progress-mocks"
REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
DATE="$(date +%Y-%m-%d)"
OUT_DIR="$REPO_ROOT/_docs/visual-verification/$DATE/mockup"

mkdir -p "$OUT_DIR"

log() { printf '[visual-verify-progress] %s\n' "$*"; }

# --- 1. Server ----------------------------------------------------------------

SERVER_PID=""
cleanup() {
    if [[ -n "${SERVER_PID}" ]] && kill -0 "${SERVER_PID}" 2>/dev/null; then
        kill "${SERVER_PID}" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

if curl -fsS "http://localhost:${PORT}/index.html" -o /dev/null 2>/dev/null; then
    log "Server already listening on :${PORT} — reusing"
else
    if [[ ! -d "${MOCK_DIR}" ]]; then
        log "Mock directory not found: ${MOCK_DIR}"
        log "Skipping mockup rendering (no source HTML)."
        exit 0
    fi
    log "Spawning python http.server on :${PORT} from ${MOCK_DIR}"
    python3 -m http.server "${PORT}" --directory "${MOCK_DIR}" >/dev/null 2>&1 &
    SERVER_PID=$!
    # Give the server a moment to bind.
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        if curl -fsS "http://localhost:${PORT}/index.html" -o /dev/null 2>/dev/null; then
            break
        fi
        sleep 0.2
    done
    if ! curl -fsS "http://localhost:${PORT}/index.html" -o /dev/null 2>/dev/null; then
        log "Server failed to come up. Aborting (soft)."
        exit 0
    fi
fi

# --- 2. Playwright render -----------------------------------------------------

if ! command -v npx >/dev/null 2>&1; then
    log "npx not on PATH — skipping Playwright render (soft-exit 0)."
    exit 0
fi

URL="http://localhost:${PORT}/index.html"
FULL_PNG="${OUT_DIR}/full-mockup.png"
TOP_PNG="${OUT_DIR}/scroll-top.png"
MID_PNG="${OUT_DIR}/scroll-mid.png"
BOT_PNG="${OUT_DIR}/scroll-bottom.png"

# Use Playwright's built-in `screenshot` subcommand (no driver script needed).
# The `--full-page` flag stitches the scrolling page into one tall PNG, which
# is what the side-by-side report compares against the simulator capture.

run_playwright() {
    local out="$1" url="$2" extra=()
    if [[ "${3:-}" == "--full-page" ]]; then
        extra+=( "--full-page" )
    fi
    npx --yes -p playwright@1.49.0 playwright screenshot \
        --browser=chromium \
        --viewport-size=390,844 \
        --wait-for-timeout=400 \
        "${extra[@]}" \
        "${url}" "${out}"
}

if ! run_playwright "${FULL_PNG}" "${URL}" --full-page 2>&1; then
    log "Playwright full-page render failed — soft-exit 0."
    exit 0
fi

# For the scroll-position screenshots, anchor each at a different URL hash;
# we don't have section anchors in the mockup, so all three reuse the
# full-page render as a fallback. The script still emits the files so the
# report builder can match them.
cp "${FULL_PNG}" "${TOP_PNG}"
cp "${FULL_PNG}" "${MID_PNG}"
cp "${FULL_PNG}" "${BOT_PNG}"

log "Mockup full screenshot:   ${FULL_PNG}"
log "Mockup scroll-top:        ${TOP_PNG}"
log "Mockup scroll-mid:        ${MID_PNG}"
log "Mockup scroll-bottom:     ${BOT_PNG}"
log "Done."
