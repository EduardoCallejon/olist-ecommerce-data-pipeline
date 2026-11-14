config {
  type:"table",
  name:"silver_order_items",
  schema:"Silver",
  dependencyTargets:[{
    name:"silver_customers"
  }]
}

WITH LAST_UPDATE AS (
  SELECT
    MAX(_FILE_NAME) AS nome_arquivo
  FROM `Bronze.order_items`
)

SELECT
  R.order_id,
  R.product_id,
  R.seller_id,
  R.price,
  CURRENT_DATETIME('America/Sao_Paulo') AS created_at,
  CURRENT_DATETIME('America/Sao_Paulo') AS update_at
FROM `Bronze.order_items` AS R
WHERE R._FILE_NAME = (
  SELECT nome_arquivo
  FROM LAST_UPDATE
)
