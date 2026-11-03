{{ config(materialized='view') }}

WITH stg_trades AS (
    SELECT * FROM {{ ref('stg_trades') }}
),

stg_market_feed AS (
    SELECT * FROM {{ ref('stg_market_feed') }}
),

enriched_trades AS (
    SELECT
        t.*,
        m.benchmark_vwap,
        m.benchmark_twap,
        -- Positive = good for the trader: BUY below VWAP, SELL above VWAP
        CASE
            WHEN t.trade_side = 'BUY' THEN (m.benchmark_vwap - t.execution_price)
            WHEN t.trade_side = 'SELL' THEN (t.execution_price - m.benchmark_vwap)
        END AS execution_slippage_raw
    FROM stg_trades AS t
    LEFT JOIN stg_market_feed AS m
        ON t.symbol = m.symbol
        AND TIME_SLICE(t.execution_timestamp, 5, 'MINUTE') = m.snapshot_timestamp
)

SELECT
    trade_id,
    order_id,
    execution_timestamp,
    target_settlement_date,
    symbol,
    venue_mic_code,
    trade_side,
    trade_quantity,
    execution_price,
    gross_principal_amount,
    settlement_currency,
    counterparty_id,
    is_duplicate_trade_id,
    is_valid_record,
    CAST(
        (execution_slippage_raw / NULLIF(benchmark_vwap, 0)) * 10000
        AS DECIMAL(12, 2)
    ) AS slippage_basis_points,
    CAST(gross_principal_amount * 0.0002 AS DECIMAL(18, 4)) AS clearing_fee_amount,
    CAST(
        CASE
            WHEN trade_side = 'BUY' THEN gross_principal_amount * 1.0002
            WHEN trade_side = 'SELL' THEN gross_principal_amount * 0.9998
        END AS DECIMAL(18, 4)
    ) AS net_settlement_amount
FROM enriched_trades
