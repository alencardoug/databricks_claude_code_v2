-- Silver: clientes limpos e conformados.
-- Dados de contato (email, telefone, endereço) ficam só na bronze: não são necessários para
-- as análises e reduzem a exposição de dados pessoais nas camadas consumidas por BI.
-- País padronizado com o mesmo mapa de silver/franchises.sql.
CREATE OR REFRESH MATERIALIZED VIEW ${medallion_catalog}.${silver_schema}.customers (
  CONSTRAINT customer_id_not_null EXPECT (customer_id IS NOT NULL) ON VIOLATION DROP ROW,
  CONSTRAINT known_country        EXPECT (country_code IS NOT NULL)
)
COMMENT 'Silver - clientes com tipos corretos e país padronizado (nome canônico + código ISO), sem dados de contato'
AS
WITH base AS (
  SELECT
    CAST(customerID AS BIGINT)        AS customer_id,
    trim(first_name)                  AS first_name,
    trim(last_name)                   AS last_name,
    trim(city)                        AS city,
    trim(state)                       AS state,
    upper(trim(country))              AS country_raw,
    trim(continent)                   AS continent,
    CAST(postal_zip_code AS STRING)   AS postal_code,
    lower(trim(gender))               AS gender,
    _ingested_at
  FROM ${medallion_catalog}.${bronze_schema}.customers
)
SELECT
  customer_id,
  first_name,
  last_name,
  concat_ws(' ', first_name, last_name) AS customer_name,
  city,
  state,
  CASE country_raw
    WHEN 'US'            THEN 'United States'
    WHEN 'USA'           THEN 'United States'
    WHEN 'UNITED STATES' THEN 'United States'
    ELSE initcap(country_raw)
  END AS country,
  CASE country_raw
    WHEN 'US'            THEN 'US'
    WHEN 'USA'           THEN 'US'
    WHEN 'UNITED STATES' THEN 'US'
    WHEN 'AUSTRALIA'     THEN 'AU'
    WHEN 'JAPAN'         THEN 'JP'
    WHEN 'CANADA'        THEN 'CA'
    WHEN 'SWEDEN'        THEN 'SE'
    WHEN 'NETHERLANDS'   THEN 'NL'
    WHEN 'ITALY'         THEN 'IT'
    WHEN 'FRANCE'        THEN 'FR'
    WHEN 'GERMANY'       THEN 'DE'
  END AS country_code,
  continent,
  postal_code,
  gender,
  _ingested_at
FROM base;
