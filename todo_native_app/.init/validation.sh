#!/usr/bin/env bash
set -euo pipefail
# validation: verify venv tools, start entrypoint.sh with per-run FLASK env, wait for readiness, show evidence, cleanup
WS="/home/kavia/workspace/code-generation/simple-todo-manager-178597-178606/todo_native_app"
cd "$WS"
if [ ! -f .venv/bin/python ]; then echo "venv missing, run deps step" >&2; exit 4; fi
# print versions (best-effort)
.venv/bin/python --version 2>/dev/null || true
.venv/bin/pip --version 2>/dev/null || true
# verify gunicorn importable
.venv/bin/python - <<'PY'
import importlib, sys
try:
    importlib.import_module('gunicorn')
except Exception as e:
    sys.exit('gunicorn not available in venv: ' + str(e))
print('tool-check: ok')
PY
LOGFILE=$(mktemp /tmp/todo_start.XXXXXX)
BG_PID=""
PGID=""
cleanup() {
  # attempt to terminate by group first, then by pid
  if [ -n "${PGID:-}" ]; then
    kill -TERM -"$PGID" 2>/dev/null || true
    sleep 1
    kill -KILL -"$PGID" 2>/dev/null || true
  elif [ -n "${BG_PID:-}" ]; then
    kill -TERM "$BG_PID" 2>/dev/null || true
    sleep 1
    kill -KILL "$BG_PID" 2>/dev/null || true
  fi
  rm -f "$LOGFILE" 2>/dev/null || true
}
trap cleanup EXIT
# start server in background with per-run FLASK env
TODO_HOST="${TODO_HOST:-127.0.0.1}"
TODO_PORT="${TODO_PORT:-8000}"
export FLASK_APP=app
export FLASK_ENV=development
# Ensure entrypoint.sh is executable
[ -x ./entrypoint.sh ] || chmod +x ./entrypoint.sh || true
# start with nohup so process survives this shell briefly; capture pid and pgid
nohup ./entrypoint.sh >"$LOGFILE" 2>&1 &
BG_PID=$!
# resolve PGID if possible
PGID=$(ps -o pgid= "$BG_PID" 2>/dev/null | tr -d ' ' || true)
URL="http://${TODO_HOST}:${TODO_PORT}/"
# wait up to 30s for readiness
attempts=0
until curl -sSf "$URL" >/dev/null 2>&1 || [ $attempts -ge 30 ]; do
  sleep 1
  attempts=$((attempts+1))
done
if ! curl -sSf "$URL" >/dev/null 2>&1; then
  echo "ERROR: server did not respond after $attempts s" >&2
  echo "--- server log ---" >&2
  tail -n 200 "$LOGFILE" >&2 || true
  exit 2
fi
# evidence: print endpoint response and server log head
curl -sS "$URL" || true
echo "--- server log (head) ---"
head -n 100 "$LOGFILE" || true
echo "validation: ok"
