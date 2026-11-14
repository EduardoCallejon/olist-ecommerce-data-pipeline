config {
  type:"table",
  name:"fact_orders",
  dataset:"Gold",
  dependencyTargets:[{
    name:"dim_sellers"
  }]
}

SELECT
  order_id,
  customer_id,
  order_status,
  data_da_compra,
  data_aprovacao,
  CURRENT_DATETIME('America/Sao_Paulo') AS created_at,
  CURRENT_DATETIME('America/Sao_Paulo') AS update_at
FROM ${ref("silver_orders")}
