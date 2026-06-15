#!/usr/bin/env bash
set -euo pipefail

ENVFILE="$(dirname "$0")/.env.supabase"

if [ ! -f "$ENVFILE" ]; then
  echo "No se encontró $ENVFILE. Crea y completa las credenciales antes de ejecutar."
  exit 1
fi

echo "Cargando variables de $ENVFILE"
export $(grep -v '^#' "$ENVFILE" | xargs)

if [ -z "${SUPABASE_DB_PASSWORD:-}" ]; then
  echo "SUPABASE_DB_PASSWORD no está definido en $ENVFILE"
  exit 1
fi

PSQL_CONN="postgresql://${SUPABASE_DB_USER}@${SUPABASE_DB_HOST}:${SUPABASE_DB_PORT}/${SUPABASE_DB_NAME}?sslmode=require"

export PGPASSWORD="$SUPABASE_DB_PASSWORD"

echo "Aplicando esquema: database/postgresql/schema/schema.sql"
psql "$PSQL_CONN" -v ON_ERROR_STOP=1 -f "$(dirname "$0")/schema/schema.sql"

echo "Aplicando datos de ejemplo: database/postgresql/seed_data/seed_data.sql"
psql "$PSQL_CONN" -v ON_ERROR_STOP=1 -f "$(dirname "$0")/seed_data/seed_data.sql"

echo "Schema y seed aplicados correctamente."
