#!/bin/bash
# Restore Chrome as the default handler, disable the plugin, remove browserhat's files.
set -euo pipefail
PLUGIN_ID=io.github.phiendp.browserhat
env -u BROWSER xdg-settings set default-web-browser google-chrome.desktop
for m in x-scheme-handler/http x-scheme-handler/https text/html x-scheme-handler/about x-scheme-handler/unknown; do
  xdg-mime default google-chrome.desktop "$m"
done
rm -f ~/.local/bin/browserhat ~/.local/share/applications/google-chrome-browserhat.desktop ~/.local/share/applications/browserhat.desktop
omarchy plugin disable "$PLUGIN_ID" 2>/dev/null || true
echo "default browser is now: $(env -u BROWSER xdg-settings get default-web-browser)"
echo "plugin disabled; remove its folder with: omarchy plugin remove $PLUGIN_ID"
