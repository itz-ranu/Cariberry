#!/bin/bash
# Sets up (once) and runs Cranberry, Cariberry's "Hey Cranberry" voice
# assistant. Cariberry.app should already be running -- Cranberry connects
# to it, but works fine (chat window, brain) even if it's briefly down.
set -euo pipefail
cd "$(dirname "$0")"

# macOS's own system Python bundles a deprecated Tk 8.5, which is known to
# render Tkinter windows unreliably (invisible/blank/non-interactive) --
# exactly the "no option to text it" symptom this chased down. Homebrew's
# python-tk formula bundles a modern, properly Cocoa-backed Tk instead, so
# prefer it when available; fall back to plain python3 otherwise.
PYTHON="python3"
for candidate in /opt/homebrew/opt/python@3.12/bin/python3.12 /opt/homebrew/opt/python@3.13/bin/python3.13 /opt/homebrew/opt/python@3.11/bin/python3.11; do
  if [ -x "$candidate" ]; then
    PYTHON="$candidate"
    break
  fi
done

VENV="cranberry/.venv"
if [ ! -d "$VENV" ]; then
  echo " creating virtualenv at $VENV (using $PYTHON)"
  "$PYTHON" -m venv "$VENV"
  "$VENV/bin/pip" install --upgrade pip
  "$VENV/bin/pip" install -r cranberry/requirements.txt
fi

exec "$VENV/bin/python" -m cranberry.main
