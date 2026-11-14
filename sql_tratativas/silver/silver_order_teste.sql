config {
  type:"assertion"
}

WITH orders AS (
  SELECT order_id
  FROM ${ref("silver_orders")}
),

nulos AS (
  SELECT
    CAST(order_id AS STRING) AS order_id,
    'order_id nulo' AS problema
  FROM orders
  WHERE order_id IS NULL
),

duplicados AS (
  SELECT
    CAST(order_id AS STRING) AS order_id,
    'order_id duplicado' AS problema
  FROM orders
  WHERE order_id IS NOT NULL
  GROUP BY order_id
  HAVING COUNT(*) > 1
)

SELECT order_id, problema
FROM nulos

UNION ALL

SELECT order_id, problema
FROM duplicados
