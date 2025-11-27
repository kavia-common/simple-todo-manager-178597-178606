#!/usr/bin/env bash
set -euo pipefail
# idempotent scaffolding for authoritative workspace
WS="/home/kavia/workspace/code-generation/simple-todo-manager-178597-178606/todo_native_app"
mkdir -p "$WS" && cd "$WS"
# requirements
cat > requirements.txt <<'REQ'
Flask>=2.0,<3.0
gunicorn>=20.0,<21.0
pytest>=7.0,<8.0
REQ
# lightweight Flask app
cat > app.py <<'PY'
import os
import sqlite3
from flask import Flask, jsonify, request

DB_PATH = os.environ.get('TODO_DB') or os.path.join(os.path.dirname(__file__), 'todo.db')
app = Flask(__name__)

def get_conn():
    # check_same_thread=False for single-process convenience; use separate connections per thread in production
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    parent = os.path.dirname(DB_PATH) or '.'
    os.makedirs(parent, exist_ok=True)
    # ensure writable (typical container user should already own workspace); attempt to set permissive mode if possible
    try:
        os.chmod(parent, 0o755)
    except Exception:
        pass
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute('CREATE TABLE IF NOT EXISTS todos (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, done INTEGER NOT NULL DEFAULT 0)')
        conn.commit()
    finally:
        conn.close()

@app.route('/')
def index():
    return jsonify({'status': 'ok'})

@app.route('/todos', methods=['GET','POST'])
def todos():
    if request.method == 'POST':
        data = request.get_json() or {}
        title = data.get('title','')
        conn = get_conn()
        try:
            cur = conn.cursor()
            cur.execute('INSERT INTO todos (title, done) VALUES (?,?)', (title,0))
            conn.commit()
            return jsonify({'id': cur.lastrowid, 'title': title}), 201
        finally:
            conn.close()
    else:
        conn = get_conn()
        try:
            rows = conn.execute('SELECT id,title,done FROM todos').fetchall()
            return jsonify([dict(r) for r in rows])
        finally:
            conn.close()
PY
# simple config
cat > config.py <<'CFG'
DEBUG = True
CFG
# entrypoint: use venv python -m gunicorn, export FLASK_* per-run, ensure DB init
cat > entrypoint.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/simple-todo-manager-178597-178606/todo_native_app"
cd "$WS"
VENV="$WS/.venv"
PY="$VENV/bin/python"
[ -x "$PY" ] || { echo "venv python missing: run deps step" >&2; exit 4; }
# export runtime env only for this process
export FLASK_APP=app
export FLASK_ENV=development
# allow override of DB path via TODO_DB env var
: "${TODO_DB:=}"
# initialize DB (runs in venv python to ensure same runtime)
"$PY" - <<PYCODE
from app import init_db
init_db()
PYCODE
# run gunicorn via venv python to avoid relying on shell activation
exec "$PY" -m gunicorn -w 1 -b 0.0.0.0:8000 app:app
SH
chmod +x entrypoint.sh
# .gitignore
cat > .gitignore <<'GI'
.venv
*.db
__pycache__
GI
# ensure DB parent directory exists and is writable
# determine default DB path used by app (if TODO_DB not set)
DB_DEFAULT="$WS/todo.db"
DB_PARENT=$(dirname "$DB_DEFAULT")
mkdir -p "$DB_PARENT"
chmod 0755 "$DB_PARENT" || true
# final validation: list created files
ls -la "$WS" | sed -n '1,200p'
