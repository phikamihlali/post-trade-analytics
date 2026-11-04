{{ config(materialized='table') }}

WITH base AS (
    SELECT * FROM {{ ref('int_trade_enrichment') }}
)

SELECT
    trade_id,
    symbol,
    execution_timestamp,
    trade_side,
    trade_quantity,
    execution_price,
    settlement_currency,
    counterparty_id,
    CASE
        WHEN execution_timestamp IS NULL THEN 'MISSING_OR_BAD_TIMESTAMP'
        WHEN execution_price IS NULL THEN 'MISSING_OR_BAD_PRICE'
        WHEN counterparty_id IS NULL THEN 'MISSING_COUNTERPARTY'
        WHEN NOT (
            (venue_mic_code IN ('XNAS', 'XNYS') AND settlement_currency = 'USD')
            OR (venue_mic_code = 'XLON' AND settlement_currency = 'GBP')
            OR (venue_mic_code = 'XAMS' AND settlement_currency = 'EUR')
        ) THEN 'CURRENCY_VENUE_MISMATCH'
        WHEN ABS(slippage_basis_points) > 100 THEN 'PRICE_SLIPPAGE_OVER_100BPS'
        WHEN is_duplicate_trade_id THEN 'DUPLICATE_TRADE_ID'
    END AS exception_reason
FROM base
QUALIFY exception_reason IS NOT NULL
