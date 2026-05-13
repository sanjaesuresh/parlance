#!/usr/bin/env bash
#
# visual-verify-build-report.sh [DATE]
#
# Build a self-contained, side-by-side HTML diff report comparing the
# simulator screenshots (left) to the mockup screenshots (right) for the
# Progress-tab rework. Default DATE = today (YYYY-MM-DD).
#
# Inputs (under _docs/visual-verification/$DATE/):
#   simulator/<name>.png   ← copied out of the XCUITest .xcresult bundle
#   mockup/<name>.png      ← from visual-verify-progress.sh
#
# Output:
#   _docs/visual-verification/$DATE/report.html
#
# Missing images are tolerated: the corresponding cell renders a
# "missing — run X" placeholder block so the report still loads end-to-end.

set -euo pipefail

DATE="${1:-$(date +%Y-%m-%d)}"
REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
ROOT_DIR="$REPO_ROOT/_docs/visual-verification/$DATE"
SIM_DIR="$ROOT_DIR/simulator"
MOCK_DIR="$ROOT_DIR/mockup"
REPORT="$ROOT_DIR/report.html"

mkdir -p "$SIM_DIR" "$MOCK_DIR"

log() { printf '[visual-verify-build-report] %s\n' "$*"; }

# Each row: <caption>|<simulator filename>|<mockup filename>
ROWS=(
    "Progress tab — Week filter|progress-week.png|full-mockup.png"
    "Progress tab — 30-day filter|progress-month.png|full-mockup.png"
    "Progress tab — All-time filter|progress-allTime.png|full-mockup.png"
    "Standout card — expanded|standout-open.png|scroll-top.png"
    "Skill card — Structure open|skill-structure-open.png|scroll-mid.png"
    "Skill card — Pace open|skill-pace-open.png|scroll-mid.png"
    "Recent sessions — Session detail|session-detail.png|scroll-bottom.png"
)

# Build rows HTML in a variable to avoid repeated subshells.
ROWS_HTML=""
for row in "${ROWS[@]}"; do
    IFS='|' read -r CAPTION SIM_NAME MOCK_NAME <<<"$row"

    SIM_REL="simulator/${SIM_NAME}"
    MOCK_REL="mockup/${MOCK_NAME}"

    if [[ -f "$SIM_DIR/$SIM_NAME" ]]; then
        SIM_CELL="<img src=\"${SIM_REL}\" alt=\"${SIM_NAME}\" />"
    else
        SIM_CELL="<div class=\"missing\"><strong>${SIM_NAME}</strong><br/>missing — run the XCUITest suite<br/>(<code>ProgressTabScreenshotTests</code>) and copy attachments to <code>${SIM_REL}</code></div>"
    fi

    if [[ -f "$MOCK_DIR/$MOCK_NAME" ]]; then
        MOCK_CELL="<img src=\"${MOCK_REL}\" alt=\"${MOCK_NAME}\" />"
    else
        MOCK_CELL="<div class=\"missing\"><strong>${MOCK_NAME}</strong><br/>missing — run <code>scripts/visual-verify-progress.sh</code></div>"
    fi

    ROWS_HTML+="
<section class=\"row\">
  <h2>${CAPTION}</h2>
  <div class=\"pair\">
    <figure>
      <figcaption>Simulator</figcaption>
      ${SIM_CELL}
    </figure>
    <figure>
      <figcaption>Mockup</figcaption>
      ${MOCK_CELL}
    </figure>
  </div>
</section>
"
done

cat >"$REPORT" <<HTML
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<title>Parlance Progress Tab — Visual Verification ${DATE}</title>
<style>
  :root {
    color-scheme: dark;
    --bg: #0e0e0f;
    --card: #18181b;
    --border: #2a2a2e;
    --text: #f3f3f0;
    --sub: #a3a3a0;
    --dim: #6c6c6a;
    --gold: #e8a838;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    padding: 32px clamp(16px, 4vw, 48px) 96px;
    background: var(--bg);
    color: var(--text);
    font: 14px/1.5 -apple-system, BlinkMacSystemFont, "SF Pro Text", Inter, system-ui, sans-serif;
  }
  header {
    margin-bottom: 32px;
    padding-bottom: 20px;
    border-bottom: 1px solid var(--border);
  }
  header h1 {
    margin: 0 0 6px;
    font: 600 22px/1.2 "SF Pro Display", -apple-system, system-ui, sans-serif;
    color: var(--text);
  }
  header .meta {
    color: var(--sub);
    font-size: 13px;
  }
  header code {
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: 4px;
    padding: 1px 6px;
    color: var(--gold);
    font-size: 12px;
  }
  section.row {
    margin: 36px 0;
  }
  section.row h2 {
    margin: 0 0 12px;
    font: 600 15px/1.2 "SF Pro Display", -apple-system, system-ui, sans-serif;
    color: var(--text);
    letter-spacing: 0.2px;
  }
  .pair {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 16px;
  }
  figure {
    margin: 0;
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 12px;
    display: flex;
    flex-direction: column;
    gap: 10px;
    min-width: 0;
  }
  figcaption {
    color: var(--dim);
    text-transform: uppercase;
    letter-spacing: 1.2px;
    font-size: 10px;
    font-weight: 500;
  }
  figure img {
    width: 100%;
    height: auto;
    display: block;
    border-radius: 8px;
    background: #000;
  }
  .missing {
    color: var(--sub);
    background: rgba(232, 168, 56, 0.06);
    border: 1px dashed rgba(232, 168, 56, 0.35);
    border-radius: 8px;
    padding: 24px 16px;
    text-align: center;
    font-size: 12px;
    line-height: 1.55;
    min-height: 200px;
    display: grid;
    align-content: center;
  }
  .missing code {
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: 4px;
    padding: 1px 5px;
    color: var(--gold);
    font-size: 11px;
  }
  footer {
    margin-top: 48px;
    color: var(--dim);
    font-size: 12px;
    border-top: 1px solid var(--border);
    padding-top: 18px;
  }
</style>
</head>
<body>
<header>
  <h1>Progress Tab — Visual Verification</h1>
  <div class="meta">Date: <strong>${DATE}</strong></div>
  <div class="meta" style="margin-top:8px;">
    Regenerate: <code>bash scripts/visual-verify-progress.sh &amp;&amp; bash scripts/visual-verify-build-report.sh ${DATE}</code>
  </div>
</header>
${ROWS_HTML}
<footer>
  Simulator screenshots come from the <code>ProgressTabScreenshotTests</code>
  XCUITest suite (attachments exported from the resulting .xcresult bundle
  into <code>${SIM_DIR#"$REPO_ROOT/"}/</code>). Mockup screenshots are
  rendered by <code>scripts/visual-verify-progress.sh</code> against
  <code>/tmp/parlance-progress-mocks/index.html</code>.
</footer>
</body>
</html>
HTML

log "Report written to: $REPORT"
