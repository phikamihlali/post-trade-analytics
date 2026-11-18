SELECT settlement_ledger_id
FROM {{ ref('fct_clearing_ledger') }}
WHERE total_buy_volume < 0 OR total_sell_volume < 0
