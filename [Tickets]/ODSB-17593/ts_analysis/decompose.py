"""KB iOS daily pb volume — additive TS decomposition with weekly period.

Inputs:
  daily_pb_spend.csv — columns: date, attr_pb, unattr_pb, total_pb, attr_pct, spend_usd

Outputs:
  decomp_components.csv — date, observed, trend, seasonal, residual
  summary.txt — variance shares + interpretation
  Notes: statsmodels.seasonal_decompose with period=7 (weekly), additive model
"""

import pandas as pd
import numpy as np
from statsmodels.tsa.seasonal import seasonal_decompose
import sys

CSV_IN = sys.argv[1] if len(sys.argv) > 1 else "daily_pb_spend.csv"
CSV_OUT = "decomp_components.csv"
SUMMARY_OUT = "summary.txt"

df = pd.read_csv(CSV_IN, parse_dates=["date"])
df = df.sort_values("date").set_index("date")

# Focus on pre-cliff window to isolate the natural weekly pattern
# (post-cliff has structural break that would pollute seasonal estimation)
pre = df.loc["2026-02-01":"2026-03-20"]["total_pb"]
full = df["total_pb"]

decomp_pre = seasonal_decompose(pre, model="additive", period=7, extrapolate_trend="freq")
decomp_full = seasonal_decompose(full, model="additive", period=7, extrapolate_trend="freq")

# Variance share (pre-cliff, natural state)
var_observed = np.var(pre - pre.mean())
var_trend = np.var(decomp_pre.trend - decomp_pre.trend.mean())
var_seasonal = np.var(decomp_pre.seasonal)
var_residual = np.var(decomp_pre.resid.dropna())

seasonal_share = var_seasonal / (var_seasonal + var_residual) * 100
trend_share = var_trend / var_observed * 100

# Day-of-week seasonal component (should repeat every 7 days)
dow_pattern = decomp_pre.seasonal.iloc[:7]
dow_pattern.index = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][:7]

# Write components
out = pd.DataFrame({
    "observed": full,
    "trend": decomp_full.trend,
    "seasonal": decomp_full.seasonal,
    "residual": decomp_full.resid,
}).reset_index()
out.to_csv(CSV_OUT, index=False)

with open(SUMMARY_OUT, "w") as f:
    f.write("KB iOS daily pb — TS decomposition\n")
    f.write("=" * 50 + "\n\n")
    f.write(f"Pre-cliff window (Feb 1 - Mar 20, n={len(pre)} days):\n")
    f.write(f"  Observed stddev: {pre.std():.1f}\n")
    f.write(f"  Trend stddev:    {decomp_pre.trend.std():.1f}\n")
    f.write(f"  Seasonal stddev: {decomp_pre.seasonal.std():.1f}\n")
    f.write(f"  Residual stddev: {decomp_pre.resid.std():.1f}\n\n")
    f.write(f"Variance explained (weekly + residual):\n")
    f.write(f"  Weekly seasonal: {seasonal_share:.1f}%\n")
    f.write(f"  Residual (noise / irregular): {100-seasonal_share:.1f}%\n\n")
    f.write(f"Day-of-week seasonal component (deviation from trend):\n")
    # Map to actual day-of-week
    first_day_dow = pre.index[0].dayofweek  # 0=Mon
    days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    for i, val in enumerate(decomp_pre.seasonal.iloc[:7]):
        d = days[(first_day_dow + i) % 7]
        f.write(f"  {d}: {val:+.1f}\n")
    f.write(f"\nInterpretation:\n")
    if seasonal_share > 60:
        f.write("  Weekly pattern dominates — chart volatility is mostly day-of-week seasonality.\n")
        f.write("  Read the chart on 7-day moving averages for underlying trend.\n")
    elif seasonal_share > 30:
        f.write("  Meaningful weekly pattern present but residual is also significant.\n")
        f.write("  True signal-to-noise requires smoothing but residual spikes are real events.\n")
    else:
        f.write("  Weekly pattern is modest — most volatility is real residual signal.\n")
        f.write("  Day-to-day changes are mostly not seasonal artifacts.\n")

print(f"Wrote {CSV_OUT} and {SUMMARY_OUT}")
print("\n=== SUMMARY ===")
with open(SUMMARY_OUT) as f:
    print(f.read())
