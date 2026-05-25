# Ecommify Database Design

Proyecto académico enfocado en el diseño conceptual, lógico y preliminar de la base de datos híbrida para **Ecommify**, una plataforma de comercio electrónico basada en PostgreSQL y MongoDB.

El objetivo principal es construir una arquitectura de datos escalable, consistente y flexible que soporte operaciones transaccionales (OLTP) y consultas analíticas (OLAP).

---

# Integrantes

-Julian Camilo Corredor Rojas 
-Brayan Estif Calderon Gomez 
-Yerlinson Maturana Serna 

---

# Objetivos del proyecto

- Diseñar un modelo entidad-relación normalizado en 3FN.
- Implementar un esquema relacional en PostgreSQL.
- Evaluar el uso de tipos avanzados como JSONB, arrays y ranges.
- Analizar extensiones de PostgreSQL como pg_trgm y PostGIS.
- Diseñar un módulo complementario en MongoDB.
- Aplicar criterios arquitectónicos usando el Teorema CAP.
- Definir una arquitectura híbrida SQL + NoSQL.

---

# Arquitectura utilizada

## PostgreSQL

Se utiliza para el módulo transaccional debido a:

- Soporte ACID.
- Integridad referencial.
- Manejo eficiente de relaciones complejas.
- Uso de constraints y normalización.
- Soporte para tipos avanzados y extensiones.

### Módulos en PostgreSQL

- Customers
- Orders
- Order Items
- Payments
- Sellers
- Products
- Reviews

---

## MongoDB

Se utiliza como complemento para:

- Información semiestructurada.
- Catálogo extendido de productos.
- Atributos dinámicos.
- Datos flexibles y escalables.

---

# Tecnologías utilizadas

| Tecnología | Uso |
|---|---|
| PostgreSQL 16 | Base de datos relacional |
| MongoDB | Base de datos NoSQL |
| Supabase | Plataforma PostgreSQL cloud |
| Google Colab | EDA y análisis |
| Python | Procesamiento de datos |
| SQL | Scripts DDL y consultas |
| GitHub | Control de versiones |

---

# Estructura del repositorio

```plaintext
Ecommify_Database_Design/
├── README.md
├── docs/
│   ├── Documento_Tecnico_Diseno.pdf
│   └── Presentacion_Ejecutiva.pdf
├── postgresql/
│   ├── schema/
│   ├── seed_data/
│   └── queries/
├── mongodb/
│   └── schema/
└── notebooks/
    └── Data_Exploration_Analysis.ipynb
