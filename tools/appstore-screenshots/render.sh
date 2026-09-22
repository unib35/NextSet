#!/bin/bash
# T-63: ko/en mockup PNGs + review sheets. Node 22+ and Google Chrome required.
# Usage: tools/appstore-screenshots/render.sh [45|60|90]
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
node "$HERE/render.mjs" "${1:-60}"
sips -g pixelWidth -g pixelHeight -g hasAlpha "$HERE/../../docs/release/screenshots/"{ko,en}/*.png
