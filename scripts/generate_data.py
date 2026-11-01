import pandas as pd
import numpy as np
import uuid
from datetime import datetime, timedelta

num_trades = 10000
np.random.seed(42)
current_time = datetime(2026, 10, 1, 9, 30, 0)
OUT = "./"

print("Initialising Post-Trade Dataset Generation Engine...")

instruments = {
    'AAPL': ('XNAS', 'USD', 110.00),
    'MSFT': ('XNYS', 'USD', 95.00),
    'HSBA': ('XLON', 'GBP', 80.00),
    'SHEL': ('XLON', 'GBP', 120.00),
    'ASML': ('XAMS', 'EUR', 100.00),
    'PHIA': ('XAMS', 'EUR', 76.00),
}
symbols = list(instruments.keys())
prices = {s: instruments[s][2] for s in symbols}
counterparties = ['MSCO', 'GSCO', 'JPM', 'BARC', 'UBSW']

# 1. Clean trades
trade_data = []
for i in range(num_trades):
    current_time += timedelta(milliseconds=int(np.random.exponential(2000)))
    sym = np.random.choice(symbols)
    venue, ccy, _ = instruments[sym]
    prices[sym] *= 1 + np.random.normal(0, 0.0005)
    exec_price = round(prices[sym] + np.random.normal(0, 0.02), 4)
    side = np.random.choice(['BUY', 'SELL'], p=[0.52, 0.48])
    qty = int(np.random.choice([100, 500, 1000, 5000, 10000],
                               p=[0.4, 0.3, 0.15, 0.1, 0.05]))
    trade_data.append({
        "trade_id": str(uuid.uuid4())[:8].upper(),
        "order_id": f"ORD_{100000 + np.random.randint(1, 1200)}",
        "execution_timestamp": current_time.strftime('%Y-%m-%d %H:%M:%S.%f')[:-3],
        "symbol": sym,
        "venue_id": venue,
        "side": side,
        "quantity": qty,
        "execution_price": exec_price,
        "currency": ccy,
        "counterparty_id": np.random.choice(counterparties),
        "settlement_cycle": "T+2"
    })
df_trades = pd.DataFrame(trade_data)

# 2. Benchmarks from CLEAN trades
tmp = df_trades.copy()
tmp["bucket"] = pd.to_datetime(tmp["execution_timestamp"]).dt.floor("5min")
tmp["notional"] = tmp["execution_price"] * tmp["quantity"]
agg = tmp.groupby(["symbol", "bucket"]).agg(
    notional=("notional", "sum"),
    volume=("quantity", "sum"),
    avg_px=("execution_price", "mean"),
).reset_index()
agg["benchmark_vwap"] = (agg["notional"] / agg["volume"]).round(4)
agg["benchmark_twap"] = agg["avg_px"].round(4)
agg["snapshot_timestamp"] = agg["bucket"].dt.strftime('%Y-%m-%d %H:%M:%S')
df_market = agg[["snapshot_timestamp", "symbol",
                 "benchmark_vwap", "benchmark_twap"]].copy()

# 3. Business outliers (100 trades, 4 types)
rng = np.random.default_rng(7)
n_out = 100
idx = rng.choice(df_trades.index.values, n_out, replace=False)
types = np.repeat(['price_spike', 'qty_fat_finger',
                   'currency_mismatch', 'duplicate'], n_out // 4)
all_ccy = ['USD', 'EUR', 'GBP']
labels, dups = [], []
for kind, i in zip(types, idx):
    row = df_trades.loc[i]
    if kind == 'price_spike':
        move = rng.choice([-1, 1]) * rng.uniform(0.03, 0.08)
        df_trades.loc[i, "execution_price"] = round(
            float(row["execution_price"]) * (1 + move), 4)
    elif kind == 'qty_fat_finger':
        df_trades.loc[i, "quantity"] = int(row["quantity"]) * int(
            rng.choice([10, 20, 50]))
    elif kind == 'currency_mismatch':
        wrong = [c for c in all_ccy if c != row["currency"]]
        df_trades.loc[i, "currency"] = str(rng.choice(wrong))
    elif kind == 'duplicate':
        dups.append(row.to_dict())
    labels.append({"trade_id": row["trade_id"], "outlier_type": kind})
if dups:
    df_trades = pd.concat([df_trades, pd.DataFrame(dups)], ignore_index=True)
df_trades = df_trades.sort_values(
    "execution_timestamp", kind="stable").reset_index(drop=True)
df_labels = pd.DataFrame(labels)

# 4. DIRTY MODE: data-quality problems (one issue per row, never on outlier rows)
rng2 = np.random.default_rng(11)
dirty = df_trades.astype(object)
eligible = dirty.index[~dirty["trade_id"].isin(set(df_labels["trade_id"]))].values

plan = [
    ("whitespace_padding", 60),
    ("lowercase_values", 60),
    ("missing_counterparty", 40),
    ("missing_price", 25),
    ("price_with_symbol", 15),
    ("bad_timestamp", 15),
    ("iso_timestamp_format", 30),
]
picks = rng2.choice(eligible, sum(n for _, n in plan), replace=False)
dq_labels, pos = [], 0
for kind, n in plan:
    for i in picks[pos:pos + n]:
        if kind == "whitespace_padding":
            dirty.loc[i, "side"] = f" {dirty.loc[i, 'side']} "
            dirty.loc[i, "counterparty_id"] = f"{dirty.loc[i, 'counterparty_id']} "
        elif kind == "lowercase_values":
            for c in ["symbol", "side", "currency"]:
                dirty.loc[i, c] = str(dirty.loc[i, c]).lower()
        elif kind == "missing_counterparty":
            dirty.loc[i, "counterparty_id"] = ""
        elif kind == "missing_price":
            dirty.loc[i, "execution_price"] = ""
        elif kind == "price_with_symbol":
            dirty.loc[i, "execution_price"] = f"${dirty.loc[i, 'execution_price']}"
        elif kind == "bad_timestamp":
            dirty.loc[i, "execution_timestamp"] = "N/A"
        elif kind == "iso_timestamp_format":
            dirty.loc[i, "execution_timestamp"] = str(
                dirty.loc[i, "execution_timestamp"]).replace(" ", "T")
        dq_labels.append({"trade_id": dirty.loc[i, "trade_id"], "dq_issue": kind})
    pos += n
df_trades = dirty
df_dq = pd.DataFrame(dq_labels)

# Market feed: a few lowercase symbols
for i in rng2.choice(df_market.index.values, 10, replace=False):
    df_market.loc[i, "symbol"] = str(df_market.loc[i, "symbol"]).lower()

# 5. Export
df_trades.to_csv(OUT + "bronze_trades.csv", index=False)
df_market.to_csv(OUT + "bronze_market_feed.csv", index=False)
df_labels.to_csv(OUT + "outlier_labels.csv", index=False)
df_dq.to_csv(OUT + "dq_labels.csv", index=False)

print(df_trades.shape, df_market.shape, df_labels.shape, df_dq.shape)
print("Saved 4 files to Downloads.") 
