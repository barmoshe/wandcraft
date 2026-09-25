# Shared by the tools/ scripts: what differs between the Linux dev container and a Mac.
#   source "$HERE/lib/platform.sh"
# Sets GODOT_TPL_ROOT (export templates), GODOT_CFG_DIR (editor settings), and defines
# with_display (runs a windowed Godot: Xvfb on Linux, the real screen on a Mac),
# sed_inplace, file_size and sha256.
if [ "$(uname)" = "Darwin" ]; then
  GODOT_TPL_ROOT="$HOME/Library/Application Support/Godot/export_templates"
  GODOT_CFG_DIR="$HOME/Library/Application Support/Godot"
  with_display() { shift 2; "$@"; }   # drops the Xvfb screen spec
  sed_inplace() { sed -i '' "$@"; }
  file_size() { stat -f %z "$1"; }
  sha256() { shasum -a 256 "$1" | cut -d' ' -f1; }
else
  GODOT_TPL_ROOT="$HOME/.local/share/godot/export_templates"
  GODOT_CFG_DIR="$HOME/.config/godot"
  with_display() { xvfb-run -a "$@"; }  # with_display -s "-screen 0 WxHx24" cmd...
  sed_inplace() { sed -i "$@"; }
  file_size() { stat -c %s "$1"; }
  sha256() { sha256sum "$1" | cut -d' ' -f1; }
fi
