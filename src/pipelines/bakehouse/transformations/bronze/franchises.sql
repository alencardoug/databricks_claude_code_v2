-- Bronze: ingestão bruta de samples.bakehouse.sales_franchises (fonte somente leitura).
-- As colunas chegam exatamente como na fonte; só os metadados de ingestão são acrescentados.
CREATE OR REFRESH STREAMING TABLE ${medallion_catalog}.${bronze_schema}.franchises
COMMENT 'Bronze - cópia bruta de samples.bakehouse.sales_franchises (franquias) com metadados de ingestão'
AS SELECT
  src.*,
  current_timestamp()                   AS _ingested_at,
  'samples.bakehouse.sales_franchises' AS _source_table
FROM STREAM(samples.bakehouse.sales_franchises) AS src;
