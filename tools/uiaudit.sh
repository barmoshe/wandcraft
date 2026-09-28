#!/usr/bin/env bash
# The overlap audit (0.20): renders every menu and HUD state at phone, tablet and desktop
# sizes with --uiaudit and lists text that collides with other text or another element
# (game/scripts/ui/ui_audit.gd). Exit 1 when anything overlaps.
# Usage: tools/uiaudit.sh [filter]   e.g. tools/uiaudit.sh boss   (runs the matching cases)
# RESES="2556x1179" limits the sizes; JOBS=4 sets how many run at once.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/platform.sh"
GAME="$HERE/../game"
OUT="$HERE/../shots/uiaudit"
FILTER="${1:-}"
RESES="${RESES:-2556x1179 2048x1536 1920x1080}"
JOBS="${JOBS:-4}"
mkdir -p "$OUT"
rm -f "$OUT"/*.png "$OUT"/*.log
"$HERE/godot.sh" --headless --path "$GAME" --import >/dev/null 2>&1

# name|args (every case also gets --uiaudit; the HUD cases add --hudstress)
CASES=(
  "start|--frames=40"
  "combat-w1|--demo --frames=240 --seed=3 --hudstress"
  "combat-full|--demo --loadout=strong --wands=3 --relics=18 --frames=240 --hudstress"
  "mini-w1|--demo --kind=mini --frames=200 --hudstress"
  "boss-w1|--demo --kind=boss --frames=200 --loadout=strong --hudstress"
  "boss-w2|--demo --world=2 --kind=boss --frames=200 --loadout=strong --hudstress"
  "mini-w3|--demo --world=3 --kind=mini --frames=200 --loadout=strong --hudstress"
  "boss-w3|--demo --world=3 --kind=boss --frames=200 --loadout=strong --relics=12 --hudstress"
  "tutorial|--tutorial --frames=120 --hudstress"
  "editor|--screen=editor --loadout=strong --frames=40"
  "editor-full|--screen=editor --loadout=strong --wands=3 --relics=18 --frames=40"
  "coach2|--screen=editor --tutorial --coach=2 --frames=40"
  "coach3|--screen=editor --tutorial --coach=3 --frames=40"
  "reward-spell|--screen=reward --offer=spell --frames=40"
  "reward-relic|--screen=reward --offer=relic --loadout=strong --frames=40"
  "shop|--screen=shop --loadout=strong --frames=40"
  "forge|--screen=forge --loadout=strong --frames=40"
  "map|--screen=map --loadout=strong --frames=40"
  "pause|--screen=pause --loadout=strong --relics=18 --frames=40"
  "glossary|--screen=pause --gloss --frames=40"
  "world2|--screen=world --to=1 --frames=120"
  "world3|--screen=world --to=2 --frames=120"
  "intro|--screen=intro --frames=90"
  "ending|--screen=ending --frames=90"
  "true-ending|--screen=true_ending --frames=90"
  "credits|--screen=credits --frames=90"
  "end-lost|--screen=end --loadout=strong --frames=60"
  "end-won|--screen=end --won=1 --loadout=strong --bounties=world2,rescue --frames=60"
  "commit|--screen=commit --frames=60"
  "hub|--screen=hub --runs=3 --wins=1 --bits=140 --residents=grep,hotfix,cache --frames=150 --hudstress"
  "hub-pkg|--screen=hub --runs=3 --bits=140 --at=pkg --frames=90 --hudstress"
  "runsheet|--screen=runsheet --runs=3 --frames=60"
  "heroes|--screen=heroes --runs=3 --frames=60"
  "bench|--screen=bench --runs=3 --frames=60"
  "pkg|--screen=pkg --runs=3 --bits=400 --frames=60"
  "board|--screen=board --runs=3 --frames=60"
  "docs|--screen=docs --runs=3 --frames=60"
  "wall|--screen=wall --runs=3 --frames=60"
  "terminal|--screen=terminal --runs=3 --frames=60"
  "hubmenu|--screen=hubmenu --runs=3 --residents=grep,hotfix,cache --frames=60"
  "grep|--screen=grep --runs=6 --residents=grep --frames=60"
  "hotfix|--screen=hotfix --runs=6 --residents=hotfix --bits=300 --frames=60"
  "cache|--screen=cache --runs=6 --residents=cache --pages=5 --frames=60"
)

run_case() {
  local res="$1" name="$2" args="$3"
  local tag="$name@$res"
  local extra=""
  [[ "$res" == "2556x1179" ]] && extra="--touchdemo"
  # shellcheck disable=SC2086
  with_display -s "-screen 0 ${res}x24" \
    "$HERE/godot.sh" --path "$GAME" --resolution "$res" --rendering-method "${RENDERER:-mobile}" -- \
    --shot="$OUT/$tag.png" --uiaudit $args $([[ "$args" == *--screen=* ]] || echo $extra) > "$OUT/$tag.log" 2>&1
  if ! grep -q "UIAUDIT: [0-9]* overlaps" "$OUT/$tag.log"; then
    echo "$tag: NO REPORT (see shots/uiaudit/$tag.log)"
    return
  fi
  grep "^UIAUDIT: " "$OUT/$tag.log" | grep -v " overlaps$" | sed "s|^UIAUDIT: |$tag  |"
}
export -f run_case with_display
export HERE GAME OUT RENDERER

for res in $RESES; do
  for c in "${CASES[@]}"; do
    name="${c%%|*}"; args="${c#*|}"
    [[ -n "$FILTER" && "$name" != *$FILTER* ]] && continue
    printf '%s\t%s\t%s\n' "$res" "$name" "$args"
  done
done | xargs -P "$JOBS" -d '\n' -I{} bash -c 'IFS=$'"'"'\t'"'"' read -r res name args <<< "{}"; run_case "$res" "$name" "$args"' > "$OUT/report.txt"

sort -o "$OUT/report.txt" "$OUT/report.txt"
cat "$OUT/report.txt"
n=$(grep -c . "$OUT/report.txt" || true)
echo "uiaudit: $n findings (shots and logs in shots/uiaudit/)"
[ "$n" -eq 0 ]
