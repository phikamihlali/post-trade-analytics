-- Upload bronze_trades.csv and bronze_market_feed.csv to the stage first (Snowsight).
-- Add FORCE = TRUE to each COPY only when deliberately reloading a file.

COPY INTO post_trade_db.bronze.bronze_trades
    (trade_id, order_id, execution_timestamp, symbol, venue_id, side,
     quantity, execution_price, currency, counterparty_id, settlement_cycle)
FROM (
    SELECT $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11
    FROM @post_trade_db.bronze.trade_stage/bronze_trades.csv
);

COPY INTO post_trade_db.bronze.bronze_market_feed
    (snapshot_timestamp, symbol, benchmark_vwap, benchmark_twap)
FROM (
    SELECT $1, $2, $3, $4
    FROM @post_trade_db.bronze.trade_stage/bronze_market_feed.csv
);
