-- Gold: desempenho de cada franquia no período completo, com localização para o mapa.
-- Franquia ativa = franquia com pelo menos uma venda no período (orders > 0).
CREATE OR REFRESH MATERIALIZED VIEW ${medallion_catalog}.${gold_schema}.franchise_performance
COMMENT 'Gold - desempenho por franquia (receita, pedidos, ticket médio, clientes, ranking) com cidade, país e coordenadas'
AS
WITH sales AS (
  SELECT
    franchise_id,
    COUNT(*)                    AS orders,
    SUM(quantity)               AS units_sold,
    SUM(total_price)            AS revenue,
    COUNT(DISTINCT customer_id) AS unique_customers,
    COUNT(DISTINCT sale_date)   AS active_days,
    MIN(sale_date)              AS first_sale_date,
    MAX(sale_date)              AS last_sale_date
  FROM ${medallion_catalog}.${silver_schema}.transactions
  GROUP BY franchise_id
)
SELECT
  f.franchise_id,
  f.franchise_name,
  f.city,
  f.district,
  f.country,
  f.country_code,
  f.size,
  f.latitude,
  f.longitude,
  COALESCE(s.orders, 0)                                    AS orders,
  COALESCE(s.units_sold, 0)                                AS units_sold,
  COALESCE(s.revenue, 0)                                   AS revenue,
  CAST(s.revenue / s.orders AS DECIMAL(12, 2))             AS avg_ticket,
  COALESCE(s.unique_customers, 0)                          AS unique_customers,
  COALESCE(s.active_days, 0)                               AS active_days,
  s.first_sale_date,
  s.last_sale_date,
  COALESCE(s.orders, 0) > 0                                AS is_active,
  COALESCE(s.revenue, 0) / SUM(COALESCE(s.revenue, 0)) OVER () AS revenue_share,
  RANK() OVER (ORDER BY COALESCE(s.revenue, 0) DESC)       AS revenue_rank
FROM ${medallion_catalog}.${silver_schema}.franchises AS f
LEFT JOIN sales AS s
  ON f.franchise_id = s.franchise_id;
