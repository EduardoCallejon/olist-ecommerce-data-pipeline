config {
  type:"table",
  name:"silver_orders",
  schema:"Silver",
  dependencyTargets:[{
    name:"silver_order_items"
  }]
}
 WITH last_update AS (
  SELECT MAX(_FILE_NAME) AS nome_arquivo
  FROM `Bronze.orders`
)

SELECT
  R.order_id,
  R.customer_id,
  UPPER(TRIM(R.order_status)) AS order_status,

  SAFE_CAST(
    NULLIF(TRIM(R.order_purchase_timestamp), '')
    AS DATETIME
  ) AS data_da_compra,

  SAFE_CAST(
    NULLIF(TRIM(R.order_approved_at), '')
    AS DATETIME
  ) AS data_aprovacao,

  CURRENT_DATETIME("America/Sao_Paulo") AS created_at,
  CURRENT_DATETIME("America/Sao_Paulo") AS updated_at

FROM `Bronze.orders` AS R
WHERE R._FILE_NAME = (
  SELECT nome_arquivo
  FROM last_update
)
