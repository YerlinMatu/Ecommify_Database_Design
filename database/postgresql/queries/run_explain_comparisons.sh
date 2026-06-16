#!/usr/bin/env bash
set -euo pipefail

# Script para ejecutar EXPLAIN ANALYZE en consultas normales y optimizadas
# Genera: explain_normal.txt, explain_optimized.txt y compare_times.txt

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR/queries"

if [ ! -f "$ROOT_DIR/.env.supabase" ]; then
  echo "Missing $ROOT_DIR/.env.supabase; create it with DB credentials." >&2
  exit 1
fi

export $(grep -v '^#' "$ROOT_DIR/.env.supabase" | xargs)
DBURL="postgresql://$SUPABASE_DB_USER@$SUPABASE_DB_HOST:$SUPABASE_DB_PORT/$SUPABASE_DB_NAME?sslmode=require"

OUT_DIR="evidence"
mkdir -p "$OUT_DIR"

echo "Running EXPLAIN on normal queries..."
PGPASSWORD="$SUPABASE_DB_PASSWORD" psql "$DBURL" -v ON_ERROR_STOP=1 -f normal_queries.sql > "$OUT_DIR/explain_normal.txt"

echo "Running EXPLAIN on optimized queries..."
PGPASSWORD="$SUPABASE_DB_PASSWORD" psql "$DBURL" -v ON_ERROR_STOP=1 -f optimized_queries_explain.sql > "$OUT_DIR/explain_optimized.txt"

echo "Extracting execution times..."
grep -iE "Execution Time:|Total runtime:" "$OUT_DIR/explain_normal.txt" > "$OUT_DIR/times_normal.txt" || true
grep -iE "Execution Time:|Total runtime:" "$OUT_DIR/explain_optimized.txt" > "$OUT_DIR/times_optimized.txt" || true

echo "Comparing times side-by-side..."
paste "$OUT_DIR/times_normal.txt" "$OUT_DIR/times_optimized.txt" > "$OUT_DIR/compare_times.txt" || true

echo "Done. Results in $ROOT_DIR/queries/evidence/"
