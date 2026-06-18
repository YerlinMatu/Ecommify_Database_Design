# Implementación MongoDB

## 1. Colecciones creadas y esquemas de documentos

### Colección: `product_catalog`

Colección principal utilizada para consultas analíticas sobre productos y métricas de negocio.

#### Esquema

```json
{
  "_id": "product_id",
  "category": {
    "pt": "informatica_acessorios",
    "en": "computers_accessories"
  },
  "specifications": {
    "name_length": 40,
    "description_length": 287,
    "photos_qty": 1,
    "weight_g": 225,
    "length_cm": 16,
    "height_cm": 10,
    "width_cm": 14
  },
  "analytics": {
    "total_sales": 56,
    "total_reviews": 12,
    "average_rating": 4.58
  }
}
```

#### Justificación

Se implementó un modelo documental utilizando el patrón **Computed Pattern**, almacenando métricas precalculadas para evitar agregaciones costosas durante la ejecución de consultas analíticas.

Las métricas almacenadas son:

* `total_sales`
* `total_reviews`
* `average_rating`

---

### Colección: `reviews`

Colección destinada al almacenamiento histórico de reseñas de productos.

#### Esquema

```json
{
  "_id": "review_id",
  "product_id": "product_id",
  "order_id": "order_id",
  "review_score": 5,
  "review_date": "2018-03-10",
  "comment_title": "Excellent",
  "comment_message": "Great product"
}
```

#### Justificación

Se optó por una estrategia de **referencing** en lugar de embedding debido al crecimiento potencial del número de reseñas por producto.

Esta decisión permite:

* Evitar documentos excesivamente grandes.
* Mantener el límite de tamaño de documento de MongoDB.
* Facilitar análisis históricos y agregaciones sobre reseñas.

---

## 2. Índices implementados

### Índice para categoría y calificación

```javascript
db.product_catalog.createIndex({
  "category.en": 1,
  "analytics.average_rating": -1
})
```

#### Justificación

Diseñado para optimizar consultas que:

1. Filtran por categoría.
2. Ordenan por calificación promedio.
3. Retornan únicamente los primeros resultados.

Consulta objetivo:

```javascript
[
  {
    $match: {
      "category.en": "electronics"
    }
  },
  {
    $sort: {
      "analytics.average_rating": -1
    }
  },
  {
    $limit: 10
  }
]
```

---

### Índice ESR (Equality, Sort, Range)

```javascript
db.product_catalog.createIndex({
  "category.en": 1,
  "analytics.average_rating": -1,
  "analytics.total_sales": 1
})
```

#### Justificación

Este índice fue construido siguiendo la estrategia **ESR (Equality, Sort, Range)** recomendada por MongoDB.

| Tipo     | Campo                    |
| -------- | ------------------------ |
| Equality | category.en              |
| Sort     | analytics.average_rating |
| Range    | analytics.total_sales    |

Permite optimizar consultas que:

* Filtran por categoría.
* Filtran por un rango mínimo de ventas.
* Ordenan por calificación.

---

## 3. Aggregation Pipelines optimizados

### Pipeline 1: Top productos electrónicos por calificación

**Objetivo:** Identificar los 10 productos mejor calificados dentro de la categoría Electronics.

```javascript
[
  {
    $match: {
      "category.en": "electronics"
    }
  },
  {
    $sort: {
      "analytics.average_rating": -1
    }
  },
  {
    $limit: 10
  }
]
```

---

### Pipeline 2: Productos electrónicos con mínimo 5 ventas

**Objetivo:** Identificar productos electrónicos con al menos cinco ventas y ordenarlos por mejor calificación.

```javascript
[
  {
    $match: {
      "category.en": "electronics",
      "analytics.total_sales": {
        $gte: 5
      }
    }
  },
  {
    $sort: {
      "analytics.average_rating": -1
    }
  },
  {
    $limit: 20
  }
]
```

---

## 4. Evidencias de mejora

### Consulta 1: Categoría + Rating

#### Antes del índice

```javascript
.explain("executionStats")
```

| Métrica        | Valor    |
| -------------- | -------- |
| Execution Time | 20 ms    |
| Docs Examined  | 32951    |
| Returned       | 10       |
| Plan           | COLLSCAN |

#### Después del índice

```javascript
.explain("executionStats")
```

| Métrica        | Valor  |
| -------------- | ------ |
| Execution Time | 0 ms   |
| Docs Examined  | 10     |
| Returned       | 10     |
| Plan           | IXSCAN |

#### Comparación

| Métrica           | Antes    | Después |
| ----------------- | -------- | ------- |
| Tiempo            | 20 ms    | 0 ms    |
| Docs examinados   | 32951    | 10      |
| Plan de ejecución | COLLSCAN | IXSCAN  |

**Mejora aproximada:** 3295 veces menos documentos examinados.

---

### Consulta 2: Categoría + Rating + Ventas

#### Antes del índice ESR

```javascript
.explain("executionStats")
```

| Métrica        | Valor    |
| -------------- | -------- |
| Execution Time | 53 ms    |
| Docs Examined  | 32951    |
| Returned       | 20       |
| Plan           | COLLSCAN |

#### Después del índice ESR

```javascript
.explain("executionStats")
```

| Métrica        | Valor  |
| -------------- | ------ |
| Execution Time | 0 ms   |
| Docs Examined  | 20     |
| Returned       | 20     |
| Plan           | IXSCAN |

#### Comparación

| Métrica           | Antes    | Después |
| ----------------- | -------- | ------- |
| Tiempo            | 53 ms    | 0 ms    |
| Docs examinados   | 32951    | 20      |
| Plan de ejecución | COLLSCAN | IXSCAN  |

**Mejora aproximada:** 1647 veces menos documentos examinados.

---

## 5. Conclusiones

* Se implementó una colección principal (`product_catalog`) optimizada para consultas analíticas.
* Se utilizó el patrón **Computed Pattern** para almacenar métricas agregadas y reducir el costo computacional de los pipelines.
* Se diseñaron índices compuestos siguiendo la estrategia **ESR (Equality, Sort, Range)**.
* Las consultas pasaron de realizar escaneos completos de colección (**COLLSCAN**) a búsquedas indexadas (**IXSCAN**).
* Se lograron mejoras significativas en rendimiento, reduciendo drásticamente la cantidad de documentos examinados y el tiempo de ejecución.
* Los pipelines implementados permiten responder consultas analíticas frecuentes de forma eficiente y escalable.
