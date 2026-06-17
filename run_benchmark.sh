#!/bin/bash

# =============================================================================
# CARGA AUTOMÁTICA DE CONFIGURACIÓN (.env.supabase)
# =============================================================================
ENV_FILE="database/postgresql/.env.supabase"

if [ -f "$ENV_FILE" ]; then
    echo -e "\033[1;33m[INFO] Cargando variables desde $ENV_FILE...\033[0m"
    # Exporta automáticamente todas las variables definidas en el archivo .env
    export $(grep -v '^#' "$ENV_FILE" | xargs)
else
    echo -e "\033[0;31m Error: No se encontró el archivo de entorno en: $ENV_FILE\033[0m"
    echo "Por favor, verifica la ruta o asegúrate de que el archivo exista."
    exit 1
fi

# Construcción de la URL de conexión usando tus variables cargadas
DB_URL="postgresql://$SUPABASE_DB_USER@$SUPABASE_DB_HOST:$SUPABASE_DB_PORT/$SUPABASE_DB_NAME?sslmode=require"
export PGPASSWORD="$SUPABASE_DB_PASSWORD"

# Colores para la terminal
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== INICIANDO BENCHMARK DE OPTIMIZACIÓN DESDE CERO ===${NC}\n"

# [El resto del script se mantiene exactamente igual...]
mkdir -p database/postgresql/queries/evidence

echo -e "${YELLOW}[1/6] Eliminando índices previos para limpiar el entorno...${NC}"
psql "$DB_URL" --pset=pager=off -c "
  DROP INDEX IF EXISTS idx_orders_purchase_brin;
  DROP INDEX IF EXISTS idx_orders_customer_purchase;
  DROP INDEX IF EXISTS idx_order_items_productid;
  DROP INDEX IF EXISTS idx_order_items_orderid;
  DROP INDEX IF EXISTS idx_orders_delivery_perf;
"
echo -e "${GREEN}✔ Entorno limpio de índices.${NC}\n"

echo -e "${YELLOW}[2/6] Ejecutando consultas BASELINE (Sin Índices)...${NC}"
psql "$DB_URL" --pset=pager=off -f database/postgresql/queries/normal_queries.sql > database/postgresql/queries/evidence/explain_ANTES.txt
echo -e "${GREEN}✔ Archivo explain_ANTES.txt generado con éxito.${NC}\n"

echo -e "${YELLOW}[3/6] Aplicando nuevos índices desde el archivo DDL...${NC}"
if [ -f database/postgresql/queries/create_indexes.sql ]; then
    psql "$DB_URL" --pset=pager=off -v ON_ERROR_STOP=1 -f database/postgresql/queries/create_indexes.sql
else
    echo -e "${RED}Error: No se encontró el archivo create_indexes.sql${NC}"
    exit 1
fi

echo -e "${YELLOW}[4/6] Ejecutando ANALYZE global para actualizar el optimizador...${NC}"
psql "$DB_URL" --pset=pager=off -v ON_ERROR_STOP=1 -c "ANALYZE orders; ANALYZE order_items; ANALYZE order_reviews; ANALYZE products;"
echo -e "${GREEN}✔ Estadísticas de la base de datos actualizadas.${NC}\n"

echo -e "${YELLOW}[5/6] Verificando índices creados en el esquema público:${NC}"
psql "$DB_URL" --pset=pager=off -v ON_ERROR_STOP=1 -c "SELECT tablename, indexname FROM pg_indexes WHERE schemaname='public' ORDER BY tablename, indexname;"

echo -e "${YELLOW}[6/6] Ejecutando consultas OPTIMIZADAS (Con Índices)...${NC}"
psql "$DB_URL" --pset=pager=off -v ON_ERROR_STOP=1 -f database/postgresql/queries/optimized_queries_explain.sql > database/postgresql/queries/evidence/explain_DESPUES.txt
echo -e "${GREEN}✔ Archivo explain_DESPUES.txt generado con éxito.${NC}\n"

if [ -f database/postgresql/queries/critical_queries.sql ]; then
    echo -e "${YELLOW}[OPCIONAL] Ejecutando consultas críticas de negocio...${NC}"
        psql "$DB_URL" --pset=pager=off -v ON_ERROR_STOP=1 -f database/postgresql/queries/critical_queries.sql > database/postgresql/queries/evidence/critical_results.txt
    echo -e "${GREEN}✔ Archivo critical_results.txt generado.${NC}\n"
fi

echo -e "${GREEN}=== BENCHMARK FINALIZADO CON ÉXITO ===${NC}"
echo -e "Los resultados listos para tu informe de Word están en: ${YELLOW}database/postgresql/queries/evidence/${NC}"