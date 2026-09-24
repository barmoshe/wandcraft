#!/usr/bin/env bash
# Plays the web build in headless Chromium as a landscape iPhone and checks the canvas fills
# the screen, there are no page errors, and sound really comes out after the first tap
# (tools/web/webtest.mjs).
#   tools/webtest.sh                  test build/web (from tools/build_web.sh)
#   tools/webtest.sh <url>            test a deployed copy, e.g. https://wandcraft-test.vercel.app/
# Needs node and Playwright with Chromium (PLAYWRIGHT_MODULE overrides the module path).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
if [ $# -gt 0 ]; then
  exec node "$HERE/web/webtest.mjs" "$1"
fi
WEB="$HERE/../build/web"
[ -f "$WEB/index.html" ] || { echo "[webtest] no build: run tools/build_web.sh first" >&2; exit 1; }
PORT="${WEBTEST_PORT:-8791}"
python3 -m http.server "$PORT" --directory "$WEB" >/dev/null 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null || true' EXIT
sleep 1
node "$HERE/web/webtest.mjs" "http://localhost:$PORT/index.html"
