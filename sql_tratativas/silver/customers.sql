config {
  type:"table",
  name:"silver_customers",
  schema:"Silver"
}

WITH LAST_UPDATE AS (
  SELECT
    MAX(_FILE_NAME) AS nome_arquivo
  FROM `Bronze.customers`
)

SELECT
  R.*,
  CURRENT_DATETIME('America/Sao_Paulo') AS created_at,
  CURRENT_DATETIME('America/Sao_Paulo') AS update_at
FROM `Bronze.customers` AS R
WHERE R._FILE_NAME = (
  SELECT nome_arquivo
  FROM LAST_UPDATE
)
