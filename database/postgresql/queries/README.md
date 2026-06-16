Queries: normal vs optimized
=================================

Archivos relevantes:
- `normal_queries.sql` — consultas baseline envueltas en `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)`.
- `optimized_queries.sql` — consultas optimizadas (sin EXPLAIN, referencia).
- `optimized_queries_explain.sql` — mismas consultas optimizadas pero con `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)`.
- `run_explain_comparisons.sh` — script que ejecuta ambos conjuntos y guarda evidencia en `evidence/`.

Cómo ejecutar (desde la raíz del repo):

```bash
# sitúate en la raíz del repo
cd /path/to/Ecommify_Database_Design

# asegúrate de que `database/postgresql/.env.supabase` contiene las credenciales (no subir al repo)
chmod 600 database/postgresql/.env.supabase

# Ejecuta el script que genera las evidencias
database/postgresql/queries/run_explain_comparisons.sh
```

Salida generada:
- `database/postgresql/queries/evidence/explain_normal.txt` — planes y métricas para consultas normales.
- `database/postgresql/queries/evidence/explain_optimized.txt` — planes y métricas para consultas optimizadas.
- `database/postgresql/queries/evidence/times_normal.txt` — líneas con `Execution Time` extraídas de la salida normal.
- `database/postgresql/queries/evidence/times_optimized.txt` — líneas con `Execution Time` extraídas de la salida optimizada.
- `database/postgresql/queries/evidence/compare_times.txt` — comparación lado a lado de los tiempos.

Recomendaciones para el README final del proyecto:
- Incluye fragmentos de ambas consultas (normal vs optimizada) y los resultados de `compare_times.txt`.
- Para pruebas reproducibles, ejecuta el script varias veces y toma la mediana de los tiempos.
- Ejecuta `ANALYZE` y/o `VACUUM ANALYZE` antes de las comparativas si acabas de cargar datos.

Resultados de la comparativa (ejecución actual)
---------------------------------------------

Se ejecutaron 7 pares de consultas (baseline vs optimizada). Cada par contiene `Planning Time` y `Execution Time` medidos con `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)`.

Tabla resumida (exec = Execution Time):

- Query 1 — Top 10 clientes por número de órdenes
	- Normal: 73.343 ms | Optimizada: 76.410 ms | Diff: +3.07 ms (optimizada +3.98%) → sin mejora (ligeramente más lenta)
- Query 2 — Órdenes por día (últimos 30 días)
	- Normal: 31.274 ms | Optimizada: 4.920 ms | Diff: -26.354 ms (optimizada -84.26%) → gran mejora
- Query 3 — Valor total por orden (Top 10)
	- Normal: 191.953 ms | Optimizada: 114.667 ms | Diff: -77.286 ms (optimizada -40.24%) → mejora notable
- Query 4 — Productos más vendidos por ingresos (Top 10)
	- Normal: 160.244 ms | Optimizada: 123.253 ms | Diff: -36.991 ms (optimizada -23.12%) → buena mejora
- Query 5 — Distribución de puntuaciones en reseñas
	- Normal: 32.080 ms | Optimizada: 40.267 ms | Diff: +8.187 ms (optimizada +25.58%) → peor rendimiento en optimizada
- Query 6 — CLTV (Customer revenue top 20)
	- Normal: 343.049 ms | Optimizada: 344.912 ms | Diff: +1.863 ms (optimizada +0.54%) → similar (ligera degradación)
- Query 7 — Tiempo medio de entrega
	- Normal: 54.232 ms | Optimizada: 53.914 ms | Diff: -0.318 ms (optimizada -0.59%) → prácticamente igual

Interpretación y recomendaciones:
- Las consultas que más mejoraron (Query 2, 3 y 4) se benefician de reducir el conjunto de datos tempranamente (filtros por rango de tiempo, agregaciones en la tabla de items antes de unir con productos). Asegúrate de mantener índices:
	- `BRIN` o `B-tree` en `orders(order_purchase_timestamp)` para rangos temporales.
	- Índices en `order_items(product_id)` y `order_items(order_id)` para agregaciones por producto/orden.
- Las consultas que empeoraron ligeramente (Query 1 y 5) pueden estar afectadas por el planificador y por el tamaño actual de las tablas; en datasets pequeños la sobrecarga de CTEs o materializaciones puede penalizar. Recomendación:
	- Re-ejecutar cada par varias veces y tomar la mediana. Si la penalización persiste, probar alternativas (usar `LIMIT` con ordenamiento por agregación con índices materiales, o evitar CTEs materializados con `MATERIALIZED`/`NOT MATERIALIZED` hints si el SGBD lo soporta).
- Para Query 6 y 7 las diferencias son marginales; mantén índices y considera ejecutar `ANALYZE` regularmente.

Archivos de evidencia:
- `database/postgresql/queries/evidence/explain_normal.txt`
- `database/postgresql/queries/evidence/explain_optimized.txt`
- `database/postgresql/queries/evidence/compare_times.txt`

Siguientes pasos sugeridos:
- Ejecutar cada comparativa 3-5 veces y usar la mediana para eliminar ruido de planificación.
- Probar `EXPLAIN (ANALYZE, FORMAT JSON)` para extraer métricas más precisas programáticamente.
- Si quieres, genero una sección del README principal con resumen y gráficos (necesitaré los archivos `explain_*.txt` o `compare_times.txt` si los vuelves a ejecutar).

**Tabla Comparativa (normal vs optimizada)**

| Query | Plan normal (ms) | Exec normal (ms) | Plan opt (ms) | Exec opt (ms) | Diff (ms) | Diff (%) |
|---|---:|---:|---:|---:|---:|---:|
| 1 — Top 10 clientes | 0.633 | 73.343 | 0.686 | 76.410 | +3.067 | +4.18% |
| 2 — Órdenes por día (30d) | 0.157 | 31.274 | 1.085 | 4.920 | -26.354 | -84.27% |
| 3 — Valor total por orden | 0.799 | 191.953 | 0.388 | 114.667 | -77.286 | -40.27% |
| 4 — Productos por ingresos | 0.508 | 160.244 | 0.670 | 123.253 | -36.991 | -23.08% |
| 5 — Distribución reseñas | 0.221 | 32.080 | 0.233 | 40.267 | +8.187 | +25.52% |
| 6 — CLTV (top 20) | 0.311 | 343.049 | 1.413 | 344.912 | +1.863 | +0.54% |
| 7 — Tiempo medio entrega | 0.160 | 54.232 | 0.133 | 53.914 | -0.318 | -0.59% |

