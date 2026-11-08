#!/usr/bin/env bash
# JagX Passport — one-command launcher.
# By JagX and JRILICENSE
#
#   ./run.sh              start the service + console on :8000
#   ./run.sh test         run the test suite
#   ./run.sh demo         run a full issue -> verify -> revoke -> verify demo
#   ./run.sh docker       build and run the container

set -euo pipefail
cd "$(dirname "$0")"

PYTHON="${PYTHON:-python3}"
PORT="${PORT:-8000}"

ensure_deps() {
  if ! "$PYTHON" -c "import fastapi, uvicorn, cryptography" >/dev/null 2>&1; then
    echo "-> installing dependencies..."
    "$PYTHON" -m pip install --quiet -r requirements.txt
  fi
}

case "${1:-serve}" in
  serve)
    ensure_deps
    echo "-> JagX Passport on http://localhost:${PORT}/  (docs at /docs)"
    exec "$PYTHON" -m jagx_passport serve --host 0.0.0.0 --port "$PORT"
    ;;
  test)
    ensure_deps
    "$PYTHON" -m pip install --quiet pytest
    exec "$PYTHON" -m pytest tests/ -q
    ;;
  demo)
    ensure_deps
    WORK="$(mktemp -d)"
    export JAGX_PASSPORT_DB="$WORK/demo.db"
    cd "$WORK"
    echo "-> demo store: $WORK"
    "$PYTHON" -m jagx_passport issuer create --name "JagX Connect" --method web \
      --domain jagx-buddy-connect.name.ng \
      --status-list "https://jagx-buddy-connect.name.ng/status/1" | tee issuer.txt
    ISSUER="$(grep -oP 'did:\s+\K\S+' issuer.txt | head -1)"
    "$PYTHON" -m jagx_passport holder create --label "Demo" | tee holder.txt
    HOLDER="$(grep -oP 'did:\s+\K\S+' holder.txt | head -1)"
    echo; echo "-> issuing a skill credential"
    "$PYTHON" -m jagx_passport issue --issuer "$ISSUER" --subject "$HOLDER" \
      --type JagXSkillCredential skill=Python level=Advanced --out skill.json
    echo; echo "-> verifying (expect verified: true)"
    "$PYTHON" -m jagx_passport verify skill.json --auto-status
    echo; echo "-> revoking"
    "$PYTHON" -m jagx_passport revoke --issuer "$ISSUER" skill.json
    echo; echo "-> verifying again (expect verified: false)"
    "$PYTHON" -m jagx_passport verify skill.json --auto-status || true
    echo; echo "demo complete — artifacts in $WORK"
    ;;
  docker)
    docker build -t jagx-passport .
    exec docker run --rm -p "${PORT}:8000" -v jagx-data:/data jagx-passport
    ;;
  *)
    echo "usage: ./run.sh [serve|test|demo|docker]" >&2
    exit 2
    ;;
esac
