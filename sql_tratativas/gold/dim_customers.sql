config {
  type:"table",
  name:"dim_customers",
  dataset:"Gold",
  dependencyTargets:[{
    name:"dim_calendar"
  }]
}

SELECT
  customer_id,
  customer_unique_id,
  customer_city,
  customer_state,
  CAST(customer_zip_code_prefix AS STRING) AS customer_zip_code_prefix,
  CURRENT_DATETIME('America/Sao_Paulo') AS created_at,
  CURRENT_DATETIME('America/Sao_Paulo') AS update_at
FROM ${ref("silver_customers")}
