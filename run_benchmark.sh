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

# =============================================================================
# RESUMEN: extraer y mostrar tiempos 'Execution Time' de los explains
# =============================================================================
ANTES_FILE="database/postgresql/queries/evidence/explain_ANTES.txt"
DESPUES_FILE="database/postgresql/queries/evidence/explain_DESPUES.txt"

echo -e "\n${YELLOW}=== RESUMEN: Tiempos de Execution Time (ms) por consulta ===${NC}"

if [ -f "$ANTES_FILE" ] || [ -f "$DESPUES_FILE" ]; then
    tmp_antes=$(mktemp)
    tmp_despues=$(mktemp)

    if [ -f "$ANTES_FILE" ]; then
        grep "Execution Time" "$ANTES_FILE" | sed -E 's/.*Execution Time: ([0-9]+(\.[0-9]+)?) ms.*/\1/' > "$tmp_antes" || true
    fi
    if [ -f "$DESPUES_FILE" ]; then
        grep "Execution Time" "$DESPUES_FILE" | sed -E 's/.*Execution Time: ([0-9]+(\.[0-9]+)?) ms.*/\1/' > "$tmp_despues" || true
    fi

    cnt_before=$(wc -l < "$tmp_antes" 2>/dev/null || echo 0)
    cnt_after=$(wc -l < "$tmp_despues" 2>/dev/null || echo 0)
    maxcnt=$(( cnt_before > cnt_after ? cnt_before : cnt_after ))

    if [ "$maxcnt" -eq 0 ]; then
        echo "No se encontraron líneas 'Execution Time' en los archivos explain."
    else
        printf "%-6s | %-12s | %-12s | %-10s\n" "Q#" "ANTES (ms)" "DESPUES (ms)" "% Mejora"
        printf "%-6s-+-%-12s-+-%-12s-+-%-10s\n" "------" "------------" "------------" "----------"

        for i in $(seq 1 $maxcnt); do
            antes_val=$(sed -n "${i}p" "$tmp_antes" 2>/dev/null || echo 0)
            despues_val=$(sed -n "${i}p" "$tmp_despues" 2>/dev/null || echo 0)
            antes_val=${antes_val:-0}
            despues_val=${despues_val:-0}
            if awk "BEGIN{exit !($antes_val > 0)}"; then
                mejora=$(awk -v a=$antes_val -v b=$despues_val 'BEGIN{printf "%.2f", ((a-b)/a)*100}')
            else
                mejora="N/A"
            fi
            printf "%-6s | %-12s | %-12s | %-9s%%\n" "Q${i}" "$antes_val" "$despues_val" "$mejora"
        done

        sum_before=$(awk '{sum+=$1} END{printf "%.2f", sum}' "$tmp_antes" 2>/dev/null || echo 0)
        sum_after=$(awk '{sum+=$1} END{printf "%.2f", sum}' "$tmp_despues" 2>/dev/null || echo 0)
        if awk "BEGIN{exit !($sum_before > 0)}"; then
            total_mejora=$(awk -v a=$sum_before -v b=$sum_after 'BEGIN{printf "%.2f", ((a-b)/a)*100}')
        else
            total_mejora="N/A"
        fi
        printf "\n%-6s | %-12s | %-12s | %-9s%%\n" "TOTAL" "$sum_before" "$sum_after" "$total_mejora"

    fi

    rm -f "$tmp_antes" "$tmp_despues"
else
    echo "No se encontraron archivos de explain para resumir."
fi
