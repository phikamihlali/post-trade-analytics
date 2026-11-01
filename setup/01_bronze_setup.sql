-- Create database and medallion schemas (Bronze, Silver & Gold) 
CREATE DATABASE IF NOT EXISTS post_trade_db;
CREATE SCHEMA IF NOT EXISTS post_trade_db.bronze;
CREATE SCHEMA IF NOT EXISTS post_trade_db.silver;
CREATE SCHEMA IF NOT EXISTS post_trade_db.gold;

-- Raw landing tables: everything is VARCHAR so nothing is rejected on load
CREATE OR REPLACE TABLE post_trade_db.bronze.bronze_trades (
    trade_id VARCHAR,
    order_id VARCHAR,
    execution_timestamp VARCHAR,
    symbol VARCHAR,
    venue_id VARCHAR,
    side VARCHAR,
    quantity VARCHAR,
    execution_price VARCHAR,
    currency VARCHAR,
    counterparty_id VARCHAR,
    settlement_cycle VARCHAR,
    _loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE post_trade_db.bronze.bronze_market_feed (
    snapshot_timestamp VARCHAR,
    symbol VARCHAR,
    benchmark_vwap VARCHAR,
    benchmark_twap VARCHAR,
    _loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Internal stage for the generated CSV files
CREATE OR REPLACE STAGE post_trade_db.bronze.trade_stage
    FILE_FORMAT = (TYPE = 'CSV' SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = '"');
