#!/usr/bin/env bash
set -euo pipefail
# dependencies step: create project venv and install pinned requirements
WS="/home/kavia/workspace/code-generation/simple-todo-manager-178597-178606/todo_native_app"
cd "$WS"
# ensure python3 venv support exists
if ! python3 -c "import venv" >/dev/null 2>&1; then
  sudo apt-get update -qq && sudo apt-get install -y python3-venv python3-pip >/dev/null
fi
# create venv only if missing
if [ ! -f "$WS/.venv/bin/python" ]; then python3 -m venv "$WS/.venv"; fi
V_PIP="$WS/.venv/bin/pip"
V_PY="$WS/.venv/bin/python"
# ensure pip exists in venv (venv on some systems may not bootstrap pip)
if [ ! -f "$V_PIP" ]; then
  python3 -m ensurepip --upgrade || true
  python3 -m pip install --upgrade pip >/dev/null
  python3 -m pip install --upgrade virtualenv >/dev/null || true
  python3 -m virtualenv -p "$(command -v python3)" "$WS/.venv" >/dev/null 2>&1 || true
fi
# upgrade pip quietly and install requirements via explicit venv pip
"$V_PIP" install --disable-pip-version-check --no-warn-script-location --upgrade pip -q
if [ -f requirements.txt ]; then
  "$V_PIP" install --disable-pip-version-check --no-warn-script-location -r requirements.txt -q
else
  echo "requirements.txt not found in $WS" >&2
  exit 1
fi
# verify imports and report versions
"$V_PY" - <<'PY'
import importlib, sys, pkgutil, subprocess
pkgs = ('flask','gunicorn','pytest')
for pkg in pkgs:
    try:
        importlib.import_module(pkg)
    except Exception as e:
        print(f"ERROR: failed to import {pkg}: {e}", file=sys.stderr)
        raise
print('python', sys.version.splitlines()[0])
# pip version
try:
    out = subprocess.check_output([sys.executable, '-m', 'pip', '--version'], text=True).strip()
    print(out)
except Exception:
    pass
PY
