#!/usr/bin/env bash
# Deploys build/web (from tools/build_web.sh) to Vercel as the project "wandcraft-test",
# live at https://wandcraft-test.vercel.app. Needs the Vercel CLI (npm i -g vercel) and a
# one-time `vercel login`. Behind an HTTPS proxy, Node needs NODE_USE_ENV_PROXY=1 (set here).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
WEB="$HERE/../build/web"
[ -f "$WEB/index.html" ] || { echo "[deploy_web] no build: run tools/build_web.sh first" >&2; exit 1; }
cp "$HERE/web/vercel.json" "$WEB/vercel.json"
export NODE_USE_ENV_PROXY=1 VERCEL_TELEMETRY_DISABLED=1
[ -f /root/.ccr/ca-bundle.crt ] && export NODE_EXTRA_CA_CERTS=/root/.ccr/ca-bundle.crt
cd "$WEB"
vercel link --yes --project wandcraft-test >/dev/null
vercel deploy --prod --yes
