-- Gold: vendas por produto no período completo (mix de produtos).
CREATE OR REFRESH MATERIALIZED VIEW ${medallion_catalog}.${gold_schema}.sales_by_product
COMMENT 'Gold - vendas por produto (pedidos, unidades, receita, preço médio e participação na receita)'
AS SELECT
  product,
  COUNT(*)                                                AS orders,
  SUM(quantity)                                           AS units_sold,
  SUM(total_price)                                        AS revenue,
  CAST(SUM(total_price) / SUM(quantity) AS DECIMAL(12, 2)) AS avg_unit_price,
  SUM(total_price) / SUM(SUM(total_price)) OVER ()        AS revenue_share,
  RANK() OVER (ORDER BY SUM(total_price) DESC)            AS revenue_rank
FROM ${medallion_catalog}.${silver_schema}.transactions
GROUP BY product;
