config {
  type:"table",
  name:"fact_order_items",
  dataset:"Gold",
  dependencyTargets:[{
    name:"fact_orders"
  }]
}
SELECT
  order_id,
  product_id,
  seller_id,
  price,
  CURRENT_DATETIME('America/Sao_Paulo') AS created_at,
  CURRENT_DATETIME('America/Sao_Paulo') AS update_at
FROM ${ref("silver_order_items")}
