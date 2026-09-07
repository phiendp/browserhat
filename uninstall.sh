#!/bin/bash
# Restore the previous default browser, disable the plugin, remove browserhat's files.
set -euo pipefail
PLUGIN_ID=io.github.phiendp.browserhat
previous=$(cat ~/.config/browserhat/previous-default-browser 2>/dev/null || true)
if [[ -z $previous ]]; then
  # No record: fall back to the first installed browser we know about.
  for d in google-chrome.desktop chromium.desktop brave-browser.desktop firefox.desktop; do
    ls {~/.local,/usr}/share/applications/$d >/dev/null 2>&1 && { previous=$d; break; }
  done
fi
if [[ -n $previous ]]; then
  env -u BROWSER xdg-settings set default-web-browser "$previous"
  for m in x-scheme-handler/http x-scheme-handler/https text/html x-scheme-handler/about x-scheme-handler/unknown; do
    xdg-mime default "$previous" "$m"
  done
fi
rm -f ~/.local/bin/browserhat ~/.local/share/applications/google-chrome-browserhat.desktop ~/.local/share/applications/browserhat.desktop
omarchy plugin disable "$PLUGIN_ID" 2>/dev/null || true
echo "default browser is now: $(env -u BROWSER xdg-settings get default-web-browser)"
echo "plugin disabled; remove its folder with: omarchy plugin remove $PLUGIN_ID"
