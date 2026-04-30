"""KB iOS daily pb — additive decomposition (manual, no statsmodels).
Trend = centered 7-day moving average.
Seasonal = mean of (observed - trend) by day-of-week, centered to sum to 0.
Residual = observed - trend - seasonal.
"""
import pandas as pd
import numpy as np
import sys

CSV_IN = sys.argv[1] if len(sys.argv) > 1 else "daily_pb_spend.csv"
df = pd.read_csv(CSV_IN, parse_dates=["date"]).sort_values("date").set_index("date")

def decompose(s, period=7):
    # Centered rolling mean (trend)
    trend = s.rolling(window=period, center=True).mean()
    detrended = s - trend
    # Seasonal: mean of detrended by DOW
    dow = s.index.dayofweek  # 0=Mon
    seasonal_by_dow = detrended.groupby(dow).mean()
    seasonal_by_dow = seasonal_by_dow - seasonal_by_dow.mean()  # center to 0
    seasonal = pd.Series([seasonal_by_dow[d] for d in dow], index=s.index)
    resid = s - trend - seasonal
    return trend, seasonal, resid, seasonal_by_dow

print(f"{'='*60}\nKB iOS daily pb — manual additive decomposition\n{'='*60}")

# Pre-cliff window (Feb 1 – Mar 20) to estimate natural weekly pattern
pre = df.loc["2026-02-01":"2026-03-20", "total_pb"].astype(float)
trend_p, season_p, resid_p, dow_p = decompose(pre, period=7)

print(f"\nPre-cliff window (Feb 1 – Mar 20, n={len(pre)}):")
print(f"  Observed stddev: {pre.std():.0f}")
print(f"  Trend stddev:    {trend_p.std():.0f}")
print(f"  Seasonal stddev: {season_p.std():.0f}")
print(f"  Residual stddev: {resid_p.dropna().std():.0f}")

# Variance shares: seasonal vs residual as fractions of seasonal+residual variance
var_s = np.var(season_p.dropna())
var_r = np.var(resid_p.dropna())
total_var = var_s + var_r
seasonal_share = var_s / total_var * 100 if total_var > 0 else 0
print(f"\nOf the non-trend variability:")
print(f"  Weekly seasonal: {seasonal_share:.1f}%")
print(f"  Residual:        {100-seasonal_share:.1f}%")

print(f"\nWeekly seasonal pattern (day-of-week deviation from trend):")
days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
for d_idx, val in dow_p.items():
    print(f"  {days[d_idx]}: {val:+.0f} pb/day")

weekday_vals = dow_p.iloc[[0,1,2,3,4]].mean()
weekend_vals = dow_p.iloc[[5,6]].mean()
print(f"\nWeekday avg deviation: {weekday_vals:+.0f}")
print(f"Weekend avg deviation: {weekend_vals:+.0f}")
print(f"Weekday/Weekend gap:   {weekday_vals - weekend_vals:.0f} pb/day")
print(f"Relative to pre-cliff mean ({pre.mean():.0f}): {(weekday_vals - weekend_vals)/pre.mean()*100:.1f}%")

# Full-window decomposition for the chart
full = df["total_pb"].astype(float)
# Use the seasonal pattern learned from pre-cliff (don't re-estimate on post-cliff
# because structural break pollutes the estimate)
trend_f = full.rolling(window=7, center=True).mean()
seasonal_f = pd.Series([dow_p[d] for d in full.index.dayofweek], index=full.index)
resid_f = full - trend_f - seasonal_f

out = pd.DataFrame({
    "observed": full,
    "trend_7dma": trend_f,
    "seasonal": seasonal_f,
    "residual": resid_f,
}).reset_index()
out.to_csv("decomp_components.csv", index=False)
print(f"\nWrote decomp_components.csv ({len(out)} rows)")

# Print key dates for validation
print("\nKey dates (observed / trend / seasonal / residual):")
for date_str in ["2026-02-15","2026-02-20","2026-03-03","2026-03-20","2026-03-21","2026-04-18"]:
    row = out[out["date"] == pd.Timestamp(date_str)].iloc[0]
    print(f"  {date_str}: obs={row['observed']:.0f}  trend={row['trend_7dma']:.0f}  season={row['seasonal']:+.0f}  resid={row['residual']:+.0f}")

# Mar 20 → Mar 21 decomposed: is it seasonal or real?
mar20 = out[out["date"] == pd.Timestamp("2026-03-20")].iloc[0]
mar21 = out[out["date"] == pd.Timestamp("2026-03-21")].iloc[0]
print(f"\nMar 20 → Mar 21 transition (the cliff):")
print(f"  Observed change: {mar21['observed']-mar20['observed']:+.0f} ({mar20['observed']:.0f} → {mar21['observed']:.0f})")
print(f"  Seasonal change: {mar21['seasonal']-mar20['seasonal']:+.0f}  (i.e. expected day-of-week effect)")
print(f"  Residual change: {mar21['residual']-mar20['residual']:+.0f}  (i.e. UNEXPLAINED anomaly)")
