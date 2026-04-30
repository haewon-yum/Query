# ODSB-17073 Follow-Up: Daily Creative Format Mix Analysis

## Context
- **Ticket**: ODSB-17073 — [HANSSEMCOLTD] CPM Fluctuation (RE_ROAS)
- **Campaign**: `QRrtrBKKVcZzcKni` | Platform: `HANSSEMCOLTD`
- **Date range**: 2025-12-08 to 2026-03-18
- **Prior finding**: CPM volatility is Simpson's Paradox — blended CPM swings based on daily creative format mix.
  - High-impression days: ni+ib dominate (90%+), blended CPM $0.15–$0.50
  - Low-impression days: vi dominates (60%+), blended CPM $3–$8

## Follow-Up Question
**What drives the drastic day-to-day shifts in creative format mix and impression volume?**

The existing report showed weekly format mix and only a narrow spike window (Jan 25–30).
This follow-up provides daily granularity across the full period and identifies causal drivers.

---

## Analysis Sections

### Section 0: Daily Format Mix — Full Period
- Daily impressions + spend + CPM broken down by `creative.format`
- Stacked area chart (impressions) + line chart (blended CPM) overlaid
- Source: `moloco-ae-view.athena.fact_dsp_all`

### Section 1: Day-of-Week Pattern by Format
- Do format mix shifts follow a weekday/weekend pattern?
- Aggregate impressions by DOW × cr_format
- Source: `moloco-ae-view.athena.fact_dsp_all`

### Section 2: Per-Format TCM Daily Trend
- TCM is computed per (exchange:cr_format) segment — divergence in per-format TCM drives differential bidding per format
- Extract avg TCM per format from `imp_1to10` (sampled impression stream)
- Source: `focal-elf-631.prod_stream_sampled.imp_1to10`
- Key question: does vi TCM stay higher while ni/ib TCM drops, explaining why vi survives throttling better?

### Section 3: Ad Group Enable/Disable × Format Mix
- Timeline: 2025-12-31 (1st AG disabled), 2026-02-02 (2nd AG disabled), 2026-02-26 (new AG created), 2026-03-03 (new AG enabled)
- Do format mix shifts align with ad group changes?
- Pull ad group config from `focal-elf-631.entity_history.prod_entity_history` (entity_type = RTB_AD_GROUP)
- If different ad groups have different format targets (e.g., one AG targeted vi only), disabling it would shift format mix

### Section 4: Budget Change × Format Mix Correlation
- Budget sawtooth pattern: 30+ changes, 145K–587K KRW
- When budget drops, throttling increases → lower TCM bids → ni/ib bids drop below bidfloor → only vi (premium) survives
- Overlay: daily budget (from entity_history) vs daily ni impression volume vs daily vi impression volume
- Source: `focal-elf-631.entity_history.prod_entity_history` + `fact_dsp_all`

### Section 5: Bidfloor by Format
- Check if ni/ib have higher bidfloor variability than vi
- When TCM drops, ni/ib are more likely to fall below bidfloor → format mix shifts to vi
- Source: `focal-elf-631.prod_stream_sampled.imp_1to10` (bid price vs floor price per format)

---

## Key Hypotheses to Test

| # | Hypothesis | Test |
|---|-----------|------|
| H1 | Per-format TCM diverges (vi TCM > ni TCM) → vi survives throttling better | Compare avg_budget_mult by cr_format from imp_1to10 |
| H2 | Budget drops → TCM drops → ni/ib bids fall below bidfloor → only vi wins | Correlate budget change timestamps with ni impression drops |
| H3 | Ad group changes directly changed the available format pool | Check if disabled AGs were format-specific (ni-only or vi-only) |
| H4 | Day-of-week: ni/ib inventory cheaper on weekdays → format mix weekday-heavy | DOW aggregation |
| H5 | Jan 27 (INCIDENT-268) disproportionately removed ni/ib due to exchange-level outage on native supply | Already confirmed in original report |

---

## Queries

See notebook `ODSB-17073_daily_format_mix.ipynb`.

## Output
- Daily format mix chart (full period) with budget overlay
- Per-format TCM daily trend
- Ad group change event markers on charts
- Summary table: which hypothesis explains what fraction of the variance
