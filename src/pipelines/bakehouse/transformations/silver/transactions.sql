-- Silver: transações limpas, tipadas e enriquecidas com franquia e cliente.
-- Cada transação é um pedido (há um produto por transação).
-- O número do cartão (cardNumber) fica só na bronze.
-- O país da venda é o país da franquia (franchise_country), e não o do cliente.
CREATE OR REFRESH MATERIALIZED VIEW ${medallion_catalog}.${silver_schema}.transactions (
  CONSTRAINT transaction_id_not_null EXPECT (transaction_id IS NOT NULL)             ON VIOLATION DROP ROW,
  CONSTRAINT franchise_id_not_null   EXPECT (franchise_id IS NOT NULL)               ON VIOLATION DROP ROW,
  CONSTRAINT customer_id_not_null    EXPECT (customer_id IS NOT NULL)                ON VIOLATION DROP ROW,
  CONSTRAINT transaction_ts_present  EXPECT (transaction_ts IS NOT NULL)             ON VIOLATION DROP ROW,
  CONSTRAINT positive_quantity       EXPECT (quantity > 0)                           ON VIOLATION DROP ROW,
  CONSTRAINT consistent_total        EXPECT (total_price = quantity * unit_price)    ON VIOLATION DROP ROW,
  CONSTRAINT valid_payment_method    EXPECT (payment_method IN ('visa', 'mastercard', 'amex')),
  CONSTRAINT known_franchise         EXPECT (franchise_name IS NOT NULL),
  CONSTRAINT known_customer          EXPECT (customer_name IS NOT NULL)
)
COMMENT 'Silver - transações de venda tipadas, com colunas de data derivadas e enriquecidas com franquia e cliente'
AS
WITH tx AS (
  SELECT
    CAST(transactionID AS BIGINT)        AS transaction_id,
    CAST(franchiseID AS BIGINT)          AS franchise_id,
    CAST(customerID AS BIGINT)           AS customer_id,
    CAST(dateTime AS TIMESTAMP)          AS transaction_ts,
    trim(product)                        AS product,
    CAST(quantity AS INT)                AS quantity,
    CAST(unitPrice AS DECIMAL(12, 2))    AS unit_price,
    CAST(totalPrice AS DECIMAL(12, 2))   AS total_price,
    lower(trim(paymentMethod))           AS payment_method,
    _ingested_at
  FROM ${medallion_catalog}.${bronze_schema}.transactions
)
SELECT
  tx.transaction_id,
  tx.transaction_ts,
  CAST(tx.transaction_ts AS DATE)                      AS sale_date,
  CAST(date_trunc('MONTH', tx.transaction_ts) AS DATE) AS sale_month,
  day(tx.transaction_ts)                               AS sale_day,
  month(tx.transaction_ts)                             AS sale_month_number,
  dayofweek(tx.transaction_ts)                         AS sale_day_of_week,
  hour(tx.transaction_ts)                              AS sale_hour,
  tx.product,
  tx.quantity,
  tx.unit_price,
  tx.total_price,
  tx.payment_method,
  tx.franchise_id,
  f.franchise_name,
  f.city         AS franchise_city,
  f.country      AS franchise_country,
  f.country_code AS franchise_country_code,
  f.latitude     AS franchise_latitude,
  f.longitude    AS franchise_longitude,
  tx.customer_id,
  c.customer_name,
  c.country      AS customer_country,
  c.country_code AS customer_country_code,
  tx._ingested_at
FROM tx
LEFT JOIN ${medallion_catalog}.${silver_schema}.franchises AS f
  ON tx.franchise_id = f.franchise_id
LEFT JOIN ${medallion_catalog}.${silver_schema}.customers AS c
  ON tx.customer_id = c.customer_id;
