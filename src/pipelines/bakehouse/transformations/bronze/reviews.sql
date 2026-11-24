-- Bronze: ingestão bruta de samples.bakehouse.media_customer_reviews (fonte somente leitura).
-- As colunas chegam exatamente como na fonte; só os metadados de ingestão são acrescentados.
CREATE OR REFRESH STREAMING TABLE ${medallion_catalog}.${bronze_schema}.reviews
COMMENT 'Bronze - cópia bruta de samples.bakehouse.media_customer_reviews (reviews de clientes) com metadados de ingestão'
AS SELECT
  src.*,
  current_timestamp()                   AS _ingested_at,
  'samples.bakehouse.media_customer_reviews' AS _source_table
FROM STREAM(samples.bakehouse.media_customer_reviews) AS src;
