config {
  type:"table",
  name:"silver_products",
  schema:"Silver",
  dependencyTargets:[{
    name:"silver_orders_teste"
  }]
}
  WITH LAST_UPDATE AS (
    SELECT
      MAX(_FILE_NAME) AS nome_arquivo
    FROM `Bronze.products`
  )
  SELECT
    R.product_id,
    R.product_category_name,
    R.product_description_lenght,
    CURRENT_DATETIME('America/Sao_Paulo') AS created_at,
    CURRENT_DATETIME('America/Sao_Paulo') AS update_at
  FROM `Bronze.products` AS R
  
  WHERE R._FILE_NAME = (
    SELECT nome_arquivo
    FROM LAST_UPDATE
  )
