#!/bin/bash
# Double-click this file (in Finder) to serve the prototype locally and
# avoid Safari/Chrome's file:// security restriction that blocks pages/*.html
# from loading ../assets/css and ../assets/js (sibling-folder resources).
# See _docs/HANDOFF.md → "Why this can't be opened by double-clicking the HTML".
cd "$(dirname "$0")"
PORT=8934
echo "Starting local server for KREEN Judge Prototype on port $PORT..."
echo "Opening http://localhost:$PORT/ in your browser."
( sleep 1 && open "http://localhost:$PORT/" ) &
python3 -m http.server "$PORT"
