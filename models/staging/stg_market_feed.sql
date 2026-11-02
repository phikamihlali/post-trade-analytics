{{ config(materialized='view') }}

WITH raw_market AS (
    SELECT * FROM {{ source('bronze', 'bronze_market_feed') }}
)

SELECT
    UPPER(TRIM(symbol)) AS symbol,
    TRY_TO_TIMESTAMP_NTZ(snapshot_timestamp) AS snapshot_timestamp,
    TRY_CAST(benchmark_vwap AS DECIMAL(18, 4)) AS benchmark_vwap,
    TRY_CAST(benchmark_twap AS DECIMAL(18, 4)) AS benchmark_twap
FROM raw_market
