SELECT settlement_ledger_id, target_settlement_date
FROM {{ ref('fct_clearing_ledger') }}
WHERE DAYOFWEEKISO(target_settlement_date) IN (6, 7)
