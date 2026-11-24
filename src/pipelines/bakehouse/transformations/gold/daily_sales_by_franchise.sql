-- Gold: vendas diárias por franquia e meio de pagamento.
-- Granularidade: sale_date x franchise_id x payment_method. O meio de pagamento entra na
-- granularidade para o dashboard montar o mix de pagamento a partir deste mart.
-- Medidas aditivas (orders, units_sold, revenue): some-as em qualquer recorte e calcule o
-- ticket médio como SUM(revenue) / SUM(orders), nunca como média de avg_ticket.
CREATE OR REFRESH MATERIALIZED VIEW ${medallion_catalog}.${gold_schema}.daily_sales_by_franchise
COMMENT 'Gold - vendas por dia, franquia e meio de pagamento (pedidos, unidades, receita, ticket médio)'
AS SELECT
  sale_date,
  franchise_id,
  franchise_name,
  franchise_city         AS city,
  franchise_country      AS country,
  franchise_country_code AS country_code,
  payment_method,
  COUNT(*)                                        AS orders,
  SUM(quantity)                                   AS units_sold,
  SUM(total_price)                                AS revenue,
  CAST(SUM(total_price) / COUNT(*) AS DECIMAL(12, 2)) AS avg_ticket
FROM ${medallion_catalog}.${silver_schema}.transactions
GROUP BY ALL;
