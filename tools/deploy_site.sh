#!/usr/bin/env bash
# The public site for the store listing: https://wandcraft-plum.vercel.app (Vercel project
# "wandcraft"; the plain wandcraft.vercel.app name belongs to someone else): a small landing page, the privacy policy and the support page that App Store
# Connect links to, with half-size screenshots. Sources live in store/.
#   tools/deploy_site.sh            build build/site and deploy it to production
#   tools/deploy_site.sh --build    only build build/site
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
OUT="$ROOT/build/site"
mkdir -p "$OUT/shots"
cp "$ROOT/store/site-index.html" "$OUT/index.html"
cp "$ROOT/store/privacy.html" "$ROOT/store/support.html" "$OUT/"
cp "$ROOT/game/assets/icon/pwa_180.png" "$OUT/icon.png"
for f in "$ROOT"/store/screenshots/*.png; do
  sips -Z 1434 "$f" --out "$OUT/shots/$(basename "$f")" >/dev/null
done
# never upload the CLI's local link data or token file
printf '%s\n' '.env*' '.vercel' > "$OUT/.vercelignore"
echo "[deploy_site] built $OUT"
[ "${1:-}" = "--build" ] && exit 0
export VERCEL_TELEMETRY_DISABLED=1
cd "$OUT"
command -v vercel >/dev/null 2>&1 || vercel() { npx -y vercel@latest "$@"; }
vercel link --yes --project wandcraft >/dev/null
# link writes a short-lived token file the site never needs: .vercelignore keeps it out
vercel deploy --prod --yes
