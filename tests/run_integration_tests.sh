#!/usr/bin/env bash
# Full integration test runner.
# Usage: bash tests/run_integration_tests.sh [--no-up] [--no-down]
#   --no-up   skip docker compose up (stack already running)
#   --no-down skip docker compose down on exit (useful for debugging)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# shellcheck source=/dev/null
[ -f .env ] && set -a && source .env && set +a

DO_UP=true
DO_DOWN=true
for arg in "$@"; do
  case $arg in
    --no-up)   DO_UP=false ;;
    --no-down) DO_DOWN=false ;;
  esac
done

AIRFLOW_API="http://localhost:8080/api/v1"
AIRFLOW_AUTH="${AIRFLOW_ADMIN_USER:-admin}:${AIRFLOW_ADMIN_PASSWORD:-changeme}"
DAG_ID="infra_test_spark_submit"

cleanup() {
  if $DO_DOWN; then
    echo ""
    echo "==> Tearing down stack..."
    docker compose down
  fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Layer 0 — start the stack
# ---------------------------------------------------------------------------
if $DO_UP; then
  echo "==> Starting stack (this may take a few minutes on first run)..."
  docker compose up --build -d --wait
fi

# ---------------------------------------------------------------------------
# Layer 1 — smoke tests
# ---------------------------------------------------------------------------
echo ""
echo "==> Layer 1: Smoke tests"
bash tests/smoke_tests.sh

# ---------------------------------------------------------------------------
# Layer 2 — PySpark integration tests (inside Spark container)
# ---------------------------------------------------------------------------
echo ""
echo "==> Layer 2: PySpark integration tests"
docker exec quant-jupyter-spark \
  python -m pytest /home/jovyan/infra-tests/ -v --tb=short

# ---------------------------------------------------------------------------
# Layer 3 — Airflow → Spark cross-service DAG test
# ---------------------------------------------------------------------------
echo ""
echo "==> Layer 3: Airflow → Spark DAG test"

# Unpause the DAG — a paused DAG accepts triggers but the scheduler never runs them
echo "  Unpausing DAG '${DAG_ID}'..."
curl -sf -X PATCH \
  -u "${AIRFLOW_AUTH}" \
  -H "Content-Type: application/json" \
  -d '{"is_paused": false}' \
  "${AIRFLOW_API}/dags/${DAG_ID}" > /dev/null

# Trigger the DAG
echo "  Triggering DAG '${DAG_ID}'..."
run_id=$(curl -sf -X POST \
  -u "${AIRFLOW_AUTH}" \
  -H "Content-Type: application/json" \
  -d '{"conf":{}}' \
  "${AIRFLOW_API}/dags/${DAG_ID}/dagRuns" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['dag_run_id'])")
echo "  DAG run ID: ${run_id}"

# Poll until the run reaches a terminal state (max 5 minutes)
echo "  Polling for completion..."
deadline=$(( $(date +%s) + 300 ))
while true; do
  state=$(curl -sf -u "${AIRFLOW_AUTH}" \
    "${AIRFLOW_API}/dags/${DAG_ID}/dagRuns/${run_id}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['state'])")
  echo "  State: ${state}"
  case "$state" in
    success) echo "  ✓ DAG completed successfully"; break ;;
    failed|upstream_failed) echo "  ✗ DAG failed (state=${state})" >&2; exit 1 ;;
  esac
  if (( $(date +%s) >= deadline )); then
    echo "  ✗ Timed out waiting for DAG to complete" >&2
    exit 1
  fi
  sleep 15
done

echo ""
echo "=== All integration tests passed ==="
