#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/simple-todo-manager-178597-178606/todo_native_app"
cd "$WS"
cat > .init/test.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
# write pytest that uses tmp_path for isolated DB
cat > test_sanity.py <<'PY'
import os
import sys

def test_index(tmp_path):
    db = tmp_path / "todo_test.db"
    os.environ['TODO_DB'] = str(db)
    # ensure fresh import
    sys.modules.pop('app', None)
    import app as myapp
    try:
        myapp.init_db()
        client = myapp.app.test_client()
        r = client.get('/')
        assert r.status_code == 200
        assert r.get_json().get('status') == 'ok'
    finally:
        if db.exists():
            db.unlink()
PY
# run pytest with explicit venv python; exit code will reflect test status
"$WS/.venv/bin/python" -m pytest -q
SH
chmod +x .init/test.sh
# execute the test script and capture its exit status
bash .init/test.sh
