#!/bin/sh
# Initializes the Unity Catalog lakehouse catalog and medallion schemas.
# Runs once as a one-shot container after unitycatalog is healthy.
# Already-exists responses are treated as success so re-runs are safe: Unity Catalog
# answers a duplicate create with 400 and an "*_ALREADY_EXISTS" error_code (not 409),
# so the body has to be inspected rather than the status alone.
set -e

UC_URL="http://unitycatalog:8080"

create_or_skip() {
  body=$(mktemp)
  http_code=$(curl -s -o "$body" -w "%{http_code}" -X POST "$1" \
    -H "Content-Type: application/json" \
    -d "$2")
  case "$http_code" in
    200|201)
      echo "  created ($http_code)"
      ;;
    *)
      if grep -q "ALREADY_EXISTS" "$body"; then
        echo "  already exists, skipping ($http_code)"
      else
        echo "  ERROR: unexpected status $http_code"
        cat "$body"
        rm -f "$body"
        exit 1
      fi
      ;;
  esac
  rm -f "$body"
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
