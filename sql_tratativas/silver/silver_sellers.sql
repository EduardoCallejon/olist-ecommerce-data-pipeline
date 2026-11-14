config {
  type:"table",
  name:"silver_sellers",
  schema:"Silver",
  dependencyTargets:[{
    name:"silver_products"
  }]
}
WITH LAST_UPDATE AS (
    SELECT
      MAX(_FILE_NAME) AS nome_arquivo
    FROM `Bronze.sellers`
  )
  SELECT
    R.seller_id,
    R.seller_city,
    R.seller_state,
    CURRENT_DATETIME('America/Sao_Paulo') AS created_at,
    CURRENT_DATETIME('America/Sao_Paulo') AS update_at
  FROM `Bronze.sellers` AS R
  
  WHERE R._FILE_NAME = (
    SELECT nome_arquivo
    FROM LAST_UPDATE
  )
