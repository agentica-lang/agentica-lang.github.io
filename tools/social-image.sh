#!/bin/sh
# Writes static/social.png, the 1200x630 default image of the link cards (params.socialImage), from
# tools/social-image.html with headless Chromium. Run from the repo root: sh tools/social-image.sh
set -eu
chrome=$(command -v chromium || command -v chromium-browser || command -v google-chrome)
"$chrome" --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --window-size=1200,630 \
  --screenshot="$PWD/static/social.png" "file://$PWD/tools/social-image.html"
