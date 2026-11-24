-- Silver: reviews de clientes classificados com ai_analyze_sentiment.
-- Rótulos: positive | neutral | negative | mixed. sentiment_score: +1 / 0 / -1 / 0.
-- Atenção: a função de IA não é determinística, e um full refresh reclassifica todos os reviews.
-- Os reviews (20 a 31/05/2024) não se sobrepõem às vendas (01 a 17/05/2024): cruzar só por franquia.
CREATE OR REFRESH MATERIALIZED VIEW ${medallion_catalog}.${silver_schema}.reviews_sentiment (
  CONSTRAINT review_id_not_null  EXPECT (review_id IS NOT NULL)                              ON VIOLATION DROP ROW,
  CONSTRAINT review_text_present EXPECT (review_text IS NOT NULL AND length(review_text) > 0) ON VIOLATION DROP ROW,
  CONSTRAINT valid_sentiment     EXPECT (sentiment IN ('positive', 'neutral', 'negative', 'mixed')),
  CONSTRAINT known_franchise     EXPECT (franchise_name IS NOT NULL)
)
COMMENT 'Silver - reviews de clientes com rótulo de sentimento (ai_analyze_sentiment) e score numérico, ligados às franquias'
AS
WITH scored AS (
  SELECT
    CAST(r.new_id AS BIGINT)                          AS review_id,
    CAST(r.franchiseID AS BIGINT)                     AS franchise_id,
    CAST(r.review_date AS TIMESTAMP)                  AS review_ts,
    CAST(r.review_date AS DATE)                       AS review_date,
    CAST(date_trunc('MONTH', r.review_date) AS DATE)  AS review_month,
    trim(r.review)                                    AS review_text,
    ai_analyze_sentiment(trim(r.review))              AS sentiment,
    r._ingested_at
  FROM ${medallion_catalog}.${bronze_schema}.reviews AS r
)
SELECT
  s.review_id,
  s.franchise_id,
  f.franchise_name,
  f.city         AS franchise_city,
  f.country      AS franchise_country,
  f.country_code AS franchise_country_code,
  s.review_ts,
  s.review_date,
  s.review_month,
  s.review_text,
  s.sentiment,
  CASE s.sentiment
    WHEN 'positive' THEN 1
    WHEN 'negative' THEN -1
    WHEN 'neutral'  THEN 0
    WHEN 'mixed'    THEN 0
  END AS sentiment_score,
  s._ingested_at
FROM scored AS s
LEFT JOIN ${medallion_catalog}.${silver_schema}.franchises AS f
  ON s.franchise_id = f.franchise_id;
