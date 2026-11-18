{{ config(severity='warn') }}

SELECT trade_id, venue_mic_code, settlement_currency
FROM {{ ref('stg_trades') }}
WHERE NOT (
    (venue_mic_code IN ('XNAS', 'XNYS') AND settlement_currency = 'USD')
    OR (venue_mic_code = 'XLON' AND settlement_currency = 'GBP')
    OR (venue_mic_code = 'XAMS' AND settlement_currency = 'EUR')
)
