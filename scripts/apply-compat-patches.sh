#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
for plugin in iSponsorBlock DontEatMyContent YTVideoOverlay YouQuality YouSpeed; do
    plugin_dir="$project_dir/Tweaks/$plugin"
    patch_file="$project_dir/patches/$plugin.patch"
    if git -C "$plugin_dir" apply --reverse --check "$patch_file" 2>/dev/null; then
        echo "$plugin compatibility patch already applied."
    elif git -C "$plugin_dir" apply --check "$patch_file"; then
        git -C "$plugin_dir" apply "$patch_file"
        echo "Applied $plugin compatibility patch."
    else
        echo "Cannot apply $plugin compatibility patch; stopping build." >&2
        exit 1
    fi
done
