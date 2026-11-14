config {
  type:"table",
  schema:"Gold",
  name:"dim_sellers",
  dependencyTargets:[{
    name:"dim_products"
  }]
}

SELECT
  seller_id,
  NULLIF(LOWER(TRIM(seller_city)), '') AS seller_city,
  UPPER(NULLIF(TRIM(seller_state), '')) AS seller_state,
  CURRENT_DATETIME('America/Sao_Paulo') AS created_at,
  CURRENT_DATETIME('America/Sao_Paulo') AS update_at
FROM ${ref("silver_sellers")}
