-- Bronze: ingestão bruta de samples.bakehouse.sales_transactions (fonte somente leitura).
-- As colunas chegam exatamente como na fonte; só os metadados de ingestão são acrescentados.
CREATE OR REFRESH STREAMING TABLE ${medallion_catalog}.${bronze_schema}.transactions
COMMENT 'Bronze - cópia bruta de samples.bakehouse.sales_transactions (transações de venda) com metadados de ingestão'
AS SELECT
  src.*,
  current_timestamp()                   AS _ingested_at,
  'samples.bakehouse.sales_transactions' AS _source_table
FROM STREAM(samples.bakehouse.sales_transactions) AS src;
