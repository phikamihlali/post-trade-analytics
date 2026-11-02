{{ config(materialized='view') }}

WITH raw_trades AS (
    SELECT * FROM {{ source('bronze', 'bronze_trades') }}
),

typed AS (
    SELECT
        CAST(trade_id AS VARCHAR(50)) AS trade_id,
        CAST(order_id AS VARCHAR(50)) AS order_id,
        -- handles both 'YYYY-MM-DD HH:MI:SS.FF' and ISO 'T' formats; 'N/A' becomes NULL
        TRY_TO_TIMESTAMP_NTZ(REPLACE(TRIM(execution_timestamp), 'T', ' ')) AS execution_timestamp,
        UPPER(TRIM(symbol)) AS symbol,
        UPPER(TRIM(venue_id)) AS venue_mic_code,
        UPPER(TRIM(side)) AS trade_side,
        TRY_CAST(quantity AS INTEGER) AS trade_quantity,
        TRY_CAST(REPLACE(TRIM(execution_price), '$', '') AS DECIMAL(18, 4)) AS execution_price,
        UPPER(TRIM(currency)) AS settlement_currency,
        UPPER(NULLIF(TRIM(counterparty_id), '')) AS counterparty_id
    FROM raw_trades
)

SELECT
    *,
    CAST(trade_quantity * execution_price AS DECIMAL(18, 4)) AS gross_principal_amount,
    COUNT(*) OVER (PARTITION BY trade_id) > 1 AS is_duplicate_trade_id,
    (
        execution_timestamp IS NOT NULL
        AND execution_price IS NOT NULL
        AND counterparty_id IS NOT NULL
    ) AS is_valid_record,
    CAST(
        DATEADD(
            DAY,
            CASE DAYOFWEEKISO(execution_timestamp)
                WHEN 1 THEN 2
                WHEN 2 THEN 2
                WHEN 7 THEN 3
                ELSE 4
            END,
            execution_timestamp
        ) AS DATE
    ) AS target_settlement_date
FROM typed
