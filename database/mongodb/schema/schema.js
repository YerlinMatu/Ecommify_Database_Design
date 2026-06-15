db.createCollection("products", {
   validator: {
      $jsonSchema: {
         bsonType: "object",
         required: ["name", "brand", "category"],
         properties: {
            name: {
               bsonType: "string",
               description: "El nombre del producto es obligatorio y debe ser un texto."
            },
            brand: {
               bsonType: "string",
               description: "La marca del producto es obligatoria."
            },
            category: {
               bsonType: "object",
               required: ["main"],
               properties: {
                  main: { bsonType: "string" },
                  sub: { bsonType: "string" }
               }
            },
            // Patrón de Atributos: Array de pares clave-valor
            technical_specifications: {
               bsonType: "array",
               items: {
                  bsonType: "object",
                  required: ["k", "v"],
                  properties: {
                     k: { bsonType: "string" },
                     v: { bsonType: ["string", "number", "bool"] }
                  }
               }
            },
            // Patrón de Subconjunto: Reseñas embebidas
            recent_reviews: {
               bsonType: "array",
               items: {
                  bsonType: "object",
                  required: ["review_id", "rating"],
                  properties: {
                     review_id: { bsonType: "string" },
                     rating: { bsonType: "int", minimum: 1, maximum: 5 },
                     comment: { bsonType: "string" }
                  }
               }
            }
         }
      }
   },
   validationAction: "error" // Rechaza el documento si no cumple el esquema
});

// Crear índices para optimizar las consultas del catálogo
db.products.createIndex({ "category.main": 1, "category.sub": 1 });
db.products.createIndex({ "technical_specifications.k": 1, "technical_specifications.v": 1 });