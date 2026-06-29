#!/usr/bin/env bash
# Smoke tests — run from the quant-infrastructure directory after `docker compose up`.
# Each check exits non-zero on failure; the overall script fails fast on the first error.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# shellcheck source=/dev/null
[ -f .env ] && set -a && source .env && set +a

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1" >&2; exit 1; }

echo "=== Smoke Tests ==="

echo "→ TimescaleDB"
docker exec quant-timescaledb \
  pg_isready -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -q \
  && pass "TimescaleDB is accepting connections" \
  || fail "TimescaleDB is not ready"

echo "→ Unity Catalog"
response=$(curl -sf "http://localhost:8081/api/2.1/unity-catalog/catalogs" 2>/dev/null) \
  || fail "Unity Catalog API did not respond"
echo "$response" | grep -q "lakehouse" \
  && pass "Unity Catalog responds and lakehouse catalog exists" \
  || fail "Unity Catalog responded but 'lakehouse' catalog is missing"

echo "→ Spark / Jupyter"
curl -sf "http://localhost:8888/api" -o /dev/null \
  && pass "Spark/Jupyter notebook server is up" \
  || fail "Spark/Jupyter server did not respond"

echo "→ Airflow"
health=$(curl -sf "http://localhost:8080/api/v1/health" 2>/dev/null) \
  || fail "Airflow health endpoint did not respond"
echo "$health" | grep -q '"status": "healthy"' \
  && pass "Airflow webserver is healthy" \
  || fail "Airflow webserver returned unhealthy status: $health"

echo "=== All smoke tests passed ==="
