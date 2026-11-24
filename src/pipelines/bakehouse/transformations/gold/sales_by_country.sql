-- Gold: vendas por país no período completo. O país é o da franquia (onde a venda ocorreu).
CREATE OR REFRESH MATERIALIZED VIEW ${medallion_catalog}.${gold_schema}.sales_by_country
COMMENT 'Gold - vendas por país da franquia (franquias, pedidos, unidades, receita, ticket médio, participação)'
AS SELECT
  franchise_country                                   AS country,
  franchise_country_code                              AS country_code,
  COUNT(DISTINCT franchise_id)                        AS franchises,
  COUNT(*)                                            AS orders,
  SUM(quantity)                                       AS units_sold,
  SUM(total_price)                                    AS revenue,
  CAST(SUM(total_price) / COUNT(*) AS DECIMAL(12, 2)) AS avg_ticket,
  SUM(total_price) / SUM(SUM(total_price)) OVER ()    AS revenue_share,
  RANK() OVER (ORDER BY SUM(total_price) DESC)        AS revenue_rank
FROM ${medallion_catalog}.${silver_schema}.transactions
GROUP BY franchise_country, franchise_country_code;
