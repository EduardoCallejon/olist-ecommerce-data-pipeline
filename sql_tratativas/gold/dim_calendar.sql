config {
  type:"table",
  name:"dim_calendar",
  dataset:"Gold",
  dependencyTargets:[{
    name:"silver_sellers"
  }]
}

WITH date_range AS (
  SELECT
    MIN(DATE(data_da_compra)) AS min_date,
    MAX(DATE(data_da_compra)) AS max_date
  FROM ${ref("silver_orders")}
  WHERE data_da_compra IS NOT NULL
),

calendar AS (
  SELECT calendar_date
  FROM date_range,
  UNNEST(GENERATE_DATE_ARRAY(min_date, max_date)) AS calendar_date
)

SELECT
  calendar_date,
  EXTRACT(YEAR FROM calendar_date) AS year,
  EXTRACT(QUARTER FROM calendar_date) AS quarter,
  EXTRACT(MONTH FROM calendar_date) AS month_number,
  FORMAT_DATE('%B', calendar_date) AS month_name,
  EXTRACT(ISOWEEK FROM calendar_date) AS iso_week,
  EXTRACT(DAY FROM calendar_date) AS day_of_month,
  EXTRACT(DAYOFWEEK FROM calendar_date) AS day_of_week_number,
  FORMAT_DATE('%A', calendar_date) AS day_of_week_name
FROM calendar
