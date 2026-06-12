#!/bin/sh
# Initializes the Unity Catalog lakehouse catalog and medallion schemas.
# Runs once as a one-shot container after unitycatalog is healthy.
# 409 responses (already exists) are treated as success so re-runs are safe.
set -e

UC_URL="http://unitycatalog:8080"

create_or_skip() {
  http_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$1" \
    -H "Content-Type: application/json" \
    -d "$2")
  case "$http_code" in
    200|201) echo "  created ($http_code)" ;;
    409)     echo "  already exists, skipping ($http_code)" ;;
    *)       echo "  ERROR: unexpected status $http_code" ; exit 1 ;;
  esac
}

echo "==> Creating catalog 'lakehouse'..."
create_or_skip \
  "$UC_URL/api/2.1/unity-catalog/catalogs" \
  '{"name":"lakehouse","comment":"Quant trading medallion catalog"}'

for schema in bronze silver gold; do
  echo "==> Creating schema 'lakehouse.$schema'..."
  create_or_skip \
    "$UC_URL/api/2.1/unity-catalog/schemas" \
    "{\"name\":\"$schema\",\"catalog_name\":\"lakehouse\"}"
done

echo "==> Unity Catalog initialization complete."
