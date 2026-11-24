-- Gold: clientes ranqueados por receita no período completo.
-- Traz todos os clientes com customer_rank; o consumidor filtra o topo (ex.: customer_rank <= 10).
-- Sem dados de contato: só ID, nome e país do cliente.
CREATE OR REFRESH MATERIALIZED VIEW ${medallion_catalog}.${gold_schema}.top_customers
COMMENT 'Gold - clientes ranqueados por receita (pedidos, unidades, receita, ticket médio, franquias visitadas)'
AS SELECT
  customer_id,
  customer_name,
  customer_country                                    AS country,
  customer_country_code                               AS country_code,
  COUNT(*)                                            AS orders,
  SUM(quantity)                                       AS units_sold,
  SUM(total_price)                                    AS revenue,
  CAST(SUM(total_price) / COUNT(*) AS DECIMAL(12, 2)) AS avg_ticket,
  COUNT(DISTINCT franchise_id)                        AS franchises_visited,
  MIN(sale_date)                                      AS first_purchase_date,
  MAX(sale_date)                                      AS last_purchase_date,
  RANK() OVER (ORDER BY SUM(total_price) DESC)        AS customer_rank
FROM ${medallion_catalog}.${silver_schema}.transactions
GROUP BY customer_id, customer_name, customer_country, customer_country_code;
