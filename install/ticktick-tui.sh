#!/usr/bin/env bash
# Build the reviewed TickTick TUI revision instead of downloading a release binary.
set -euo pipefail
revision=c1e5a5e1a03ca091a66994fb2f51e82bd3de32d1
build_dir=$(mktemp -d)
staged_binary=''
trap 'rm -rf -- "$build_dir"; if [[ -n $staged_binary ]]; then rm -f -- "$staged_binary"; fi' EXIT
printf 'Building TickTick TUI from reviewed commit %s.\n' "$revision"
git init -q "$build_dir/source"
git -C "$build_dir/source" remote add origin https://github.com/raccoon-overlord-dev/ticktick-tui.git
git -C "$build_dir/source" fetch --depth 1 origin "$revision"
git -C "$build_dir/source" checkout --detach FETCH_HEAD
[[ $(git -C "$build_dir/source" rev-parse HEAD) == "$revision" ]]
(
    cd "$build_dir/source"
    CGO_ENABLED=0 go build -o "$build_dir/ttui" ./cmd/ttui
)
"$build_dir/ttui" --version
mkdir -p "$HOME/.local/bin"
staged_binary=$(mktemp "$HOME/.local/bin/.ttui.XXXXXXXX")
install -m 755 "$build_dir/ttui" "$staged_binary"
mv -f -- "$staged_binary" "$HOME/.local/bin/ttui"
printf 'Installed TickTick TUI to %s/.local/bin/ttui.\n' "$HOME"
