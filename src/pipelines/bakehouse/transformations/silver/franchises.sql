-- Silver: franquias limpas e conformadas.
-- País padronizado: `country` tem o nome canônico ('US' e 'USA' viram 'United States')
-- e `country_code` tem o código ISO-3166 alfa-2. O mesmo mapa é usado em silver/customers.sql.
CREATE OR REFRESH MATERIALIZED VIEW ${medallion_catalog}.${silver_schema}.franchises (
  CONSTRAINT franchise_id_not_null EXPECT (franchise_id IS NOT NULL) ON VIOLATION DROP ROW,
  CONSTRAINT known_country         EXPECT (country_code IS NOT NULL),
  CONSTRAINT valid_coordinates     EXPECT (latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180)
)
COMMENT 'Silver - franquias com tipos corretos, país padronizado (nome canônico + código ISO) e coordenadas'
AS
WITH base AS (
  SELECT
    CAST(franchiseID AS BIGINT)  AS franchise_id,
    trim(name)                   AS franchise_name,
    trim(city)                   AS city,
    trim(district)               AS district,
    trim(zipcode)                AS zipcode,
    upper(trim(country))         AS country_raw,
    lower(trim(size))            AS size,
    CAST(latitude AS DOUBLE)     AS latitude,
    CAST(longitude AS DOUBLE)    AS longitude,
    CAST(supplierID AS BIGINT)   AS supplier_id,
    _ingested_at
  FROM ${medallion_catalog}.${bronze_schema}.franchises
)
SELECT
  franchise_id,
  franchise_name,
  city,
  district,
  zipcode,
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
  size,
  latitude,
  longitude,
  supplier_id,
  _ingested_at
FROM base;
