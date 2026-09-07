#!/bin/bash
# Install browserhat: enable the Omarchy shell plugin and register the link handler.
set -euo pipefail
PLUGIN_ID=io.github.phiendp.browserhat
PLUGIN_DIR=~/.config/omarchy/plugins/$PLUGIN_ID
here=$(cd "$(dirname "$0")" && pwd -P)

# `omarchy plugin add <git-url>` clones straight into $PLUGIN_DIR. When this
# script runs from a checkout elsewhere, copy the plugin there first (symlinks
# are rejected inside plugin folders, so a real copy is required).
if [[ $here != "$(readlink -f "$PLUGIN_DIR")" ]]; then
  mkdir -p "$PLUGIN_DIR"
  cp -a "$here"/. "$PLUGIN_DIR"/
fi

omarchy plugin validate "$PLUGIN_DIR"
omarchy-shell shell rescanPlugins >/dev/null
omarchy plugin list --json | jq -e --arg id "$PLUGIN_ID" 'any(.[]; .id == $id and .enabled)' >/dev/null \
  || omarchy plugin enable "$PLUGIN_ID"

# Remember the current default browser so uninstall.sh can restore it.
mkdir -p ~/.config/browserhat
previous=$(env -u BROWSER xdg-settings get default-web-browser 2>/dev/null || true)
if [[ -n $previous && $previous != google-chrome-browserhat.desktop ]]; then
  printf '%s\n' "$previous" > ~/.config/browserhat/previous-default-browser
fi

mkdir -p ~/.local/bin ~/.local/share/applications
ln -sf "$PLUGIN_DIR/browserhat" ~/.local/bin/browserhat
install -m644 "$PLUGIN_DIR/google-chrome-browserhat.desktop" ~/.local/share/applications/google-chrome-browserhat.desktop
update-desktop-database ~/.local/share/applications 2>/dev/null || true
env -u BROWSER xdg-settings set default-web-browser google-chrome-browserhat.desktop
for m in x-scheme-handler/http x-scheme-handler/https text/html x-scheme-handler/about x-scheme-handler/unknown; do
  xdg-mime default google-chrome-browserhat.desktop "$m"
done
echo "plugin:          $PLUGIN_ID (enabled)"
echo "default browser: $(env -u BROWSER xdg-settings get default-web-browser)"
echo "targets:"; browserhat list
