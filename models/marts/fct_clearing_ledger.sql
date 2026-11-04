{{ config(materialized='table') }}

WITH silver_trades AS (
    SELECT * FROM {{ ref('int_trade_enrichment') }}
    -- keep one copy of each duplicated trade_id
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY trade_id ORDER BY execution_timestamp
    ) = 1
),

valid_trades AS (
    SELECT * FROM silver_trades
    WHERE is_valid_record
        AND (
            (venue_mic_code IN ('XNAS', 'XNYS') AND settlement_currency = 'USD')
            OR (venue_mic_code = 'XLON' AND settlement_currency = 'GBP')
            OR (venue_mic_code = 'XAMS' AND settlement_currency = 'EUR')
        )
),

netted AS (
    SELECT
        target_settlement_date,
        counterparty_id,
        settlement_currency,
        SUM(CASE WHEN trade_side = 'BUY' THEN trade_quantity ELSE 0 END) AS total_buy_volume,
        SUM(CASE WHEN trade_side = 'SELL' THEN trade_quantity ELSE 0 END) AS total_sell_volume,
        SUM(CASE WHEN trade_side = 'BUY' THEN trade_quantity ELSE -trade_quantity END)
            AS net_settlement_quantity,
        SUM(CASE WHEN trade_side = 'BUY' THEN net_settlement_amount ELSE -net_settlement_amount END)
            AS net_cash_obligation,
        SUM(clearing_fee_amount) AS total_clearing_fees,
        SUM(CASE WHEN slippage_basis_points IS NOT NULL
                 THEN slippage_basis_points * gross_principal_amount END)
        / NULLIF(SUM(CASE WHEN slippage_basis_points IS NOT NULL
                          THEN gross_principal_amount END), 0) AS weighted_slippage_bps,
        COUNT(trade_id) AS total_execution_fills_count,
        MAX(execution_timestamp) AS max_execution_timestamp
    FROM valid_trades
    GROUP BY target_settlement_date, counterparty_id, settlement_currency
)

SELECT
    {{ dbt_utils.generate_surrogate_key([
        'target_settlement_date', 'counterparty_id', 'settlement_currency'
    ]) }} AS settlement_ledger_id,
    target_settlement_date,
    counterparty_id,
    settlement_currency,
    total_buy_volume,
    total_sell_volume,
    net_settlement_quantity,
    net_cash_obligation,
    total_clearing_fees,
    CAST(weighted_slippage_bps AS DECIMAL(12, 2)) AS avg_slippage_bps,
    total_execution_fills_count,
    CASE
        WHEN net_cash_obligation > 0 THEN 'PAYER'
        WHEN net_cash_obligation < 0 THEN 'RECEIVER'
        ELSE 'NET_ZERO'
    END AS cash_settlement_direction,
    max_execution_timestamp,
    CURRENT_TIMESTAMP() AS dbt_updated_at
FROM netted
