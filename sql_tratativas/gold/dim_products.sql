config {
  type:"table",
  schema:"Gold",
  name:"dim_products",
  dependencyTargets:[{
    name:"dim_customers"
  }]
}

SELECT
  product_id,
  NULLIF(LOWER(TRIM(product_category_name)), '') AS product_category_name,
  product_description_lenght,
  CURRENT_DATETIME('America/Sao_Paulo') AS created_at,
  CURRENT_DATETIME('America/Sao_Paulo') AS update_at
FROM ${ref("silver_products")}
