-- Gold: sentimento dos reviews por franquia (período dos reviews: 20 a 31/05/2024).
-- net_sentiment_score = média do sentiment_score (+1 positivo, 0 neutro/misto, -1 negativo).
CREATE OR REFRESH MATERIALIZED VIEW ${medallion_catalog}.${gold_schema}.sentiment_by_franchise
COMMENT 'Gold - sentimento dos reviews por franquia (contagens por rótulo, percentuais e score líquido)'
AS SELECT
  f.franchise_id,
  f.franchise_name,
  f.city,
  f.country,
  f.country_code,
  COUNT(r.review_id)                                          AS reviews,
  COUNT_IF(r.sentiment = 'positive')                          AS positive_reviews,
  COUNT_IF(r.sentiment = 'neutral')                           AS neutral_reviews,
  COUNT_IF(r.sentiment = 'mixed')                             AS mixed_reviews,
  COUNT_IF(r.sentiment = 'negative')                          AS negative_reviews,
  COUNT_IF(r.sentiment = 'positive') / COUNT(r.review_id)     AS pct_positive,
  COUNT_IF(r.sentiment = 'negative') / COUNT(r.review_id)     AS pct_negative,
  CAST(AVG(r.sentiment_score) AS DECIMAL(5, 2))               AS net_sentiment_score
FROM ${medallion_catalog}.${silver_schema}.franchises AS f
LEFT JOIN ${medallion_catalog}.${silver_schema}.reviews_sentiment AS r
  ON f.franchise_id = r.franchise_id
GROUP BY f.franchise_id, f.franchise_name, f.city, f.country, f.country_code;
