WITH deduped AS (
    SELECT trade_id
    FROM {{ ref('int_trade_enrichment') }}
    WHERE is_valid_record
        AND (
            (venue_mic_code IN ('XNAS', 'XNYS') AND settlement_currency = 'USD')
            OR (venue_mic_code = 'XLON' AND settlement_currency = 'GBP')
            OR (venue_mic_code = 'XAMS' AND settlement_currency = 'EUR')
        )
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY trade_id ORDER BY execution_timestamp
    ) = 1
),

expected AS (
    SELECT COUNT(*) AS n FROM deduped
),

actual AS (
    SELECT SUM(total_execution_fills_count) AS n
    FROM {{ ref('fct_clearing_ledger') }}
)

SELECT expected.n AS expected_trades, actual.n AS ledger_trades
FROM expected
CROSS JOIN actual
WHERE expected.n <> actual.n
