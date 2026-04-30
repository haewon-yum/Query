# GDS Storytelling Workshop — Prep Session Log

**Workshop:** Beyond the Model, Workshop 2 — Storytelling with Data
**Presentation:** https://docs.google.com/presentation/d/1DzOow71NqxdoImjwR8dTUK5EvBV-wMBSUEcV2Vb_qtA
**Case slides copy (4 slides):** https://docs.google.com/presentation/d/1PKLikw3CIAkYyOCBQL854CsLczZDmCQoHn8XoLV8MyI
**Prep started:** 2026-04-09

---

## Session 2026-04-09 / 2026-04-10

### Context
- **Scope:** Transform the retention placeholder example in slides 7–10 into a real case; write facilitator script; find source data for the case claim
- **Files produced:**
  - `GDS_Storytelling_Workshop_Facilitator_Guide.md` (this folder)
  - `case_study_data.ipynb` (this folder)
  - New 4-slide presentation: https://docs.google.com/presentation/d/1PKLikw3CIAkYyOCBQL854CsLczZDmCQoHn8XoLV8MyI

### Process & Hypotheses

| Step | Question / Task | Approach | Finding |
|------|----------------|----------|---------|
| 1 | What is the current format of slides 7–10? | Slides API read | Slides use S/C/R framework with retention placeholder example |
| 2 | Does the case doc (m_rev_5) map well to that format? | Read Doc ID `1emNudGdvcbX2KDnQTWduDcylaX-ptBp-3uZNSERw8yo` | Yes — doc already pre-structures into S/C/R; 2 supporting tables embedded |
| 3 | Create new 4-slide deck preserving original formatting | Drive API copy + delete slides 1–6 and 11–20 + text replaceAllText | Created `1PKLikw3CIAkYyOCBQL854CsLczZDmCQoHn8XoLV8MyI`, all 9 text replacements confirmed 1 match each |
| 4 | Write facilitator script for full 20-slide presentation | Manual script based on slide content read | Full script with key points + word-for-word script per slide; simplified for non-native delivery |
| 5 | Is there actual proof for "CPA campaign underperformed in US"? | Glean search → found client + BQ campaign IDs → BQ query | Fully confirmed (see findings below) |

### Key Findings

1. **Client identified: Treeplla (Office Cat iOS/Android)** — The m_rev_5 case is a real Treeplla campaign. Advertiser ID: `nBsHBgiHeOljDuHW`. US campaign ID: `n5zuQbwIHRXTofes`, T2 campaign ID: `r9oP1lWrn42uKX5w`.

2. **US CPA was 6.2× worse than T2** — BQ query over full campaign lifetime (2025-03-13 to 2025-08-11):
   - US: $2,362 spend / 11 m_rev_5 conversions / **CPA $214.77** / i2a 0.82%
   - T2: $15,924 spend / 461 conversions / **CPA $34.54** / i2a 4.64%
   - T2 country range: DEU $20.36 → GBR $43.31
   - US campaign was paused on June 15; T2 ran to August 11

3. **Root cause is conversion rate, not CPI** — CPI is comparable ($1.75 US vs $1.60 T2). The problem is that only 0.82% of US installs ever fire m_rev_5, vs 4.64% in T2.

4. **D7 cumulative reach confirms structural timing mismatch** — From raw investigation sheet `1Gibyp6O2zJ55iUVd0-c3cud6pdQ7OKiIKZHMA7TGdrY`:
   - US: 70.1% of m_rev_5 users fire within D7
   - T2: 89.6% fire within D7
   - This means the D7 CPA campaign window captures only 70% of US signal vs 90%+ T2

5. **Whale vs. minnow structure confirmed by purchase distribution** — US P75 first purchase = $8.00 vs AUS $3.10, CAN $2.90, DEU $3.00. US avg IAP count before m_rev_5: 5.7 ($31.40 total); T2: 1–2 IAPs ($3–7 total).

6. **Original presentation has duplicate slides (11–14)** — Slides 7–10 now have updated m_rev_5 content (IDs: `g3dd5dda8d8e_*`). Slides 11–14 are the old retention example (IDs: `g3cf2f421490_*`). **Delete slides 11–14 before delivering.**

### Source Documents
| Resource | Link |
|----------|------|
| Case narrative doc | https://docs.google.com/document/d/1emNudGdvcbX2KDnQTWduDcylaX-ptBp-3uZNSERw8yo |
| Raw investigation sheet | https://docs.google.com/spreadsheets/d/1Gibyp6O2zJ55iUVd0-c3cud6pdQ7OKiIKZHMA7TGdrY |
| Amy/Jamie notes (campaign IDs) | https://docs.google.com/document/d/1oCRIrAWW5BkWWVJTHIdQrG6n5QI8zrXkjgfTxuu4Cbo |
| Jira follow-up ticket | https://mlc.atlassian.net/browse/ODSB-16227 |
| BQ geo detail CSV | `~/claude-bq-agent/tmp/data/20260410_112424_0b76.csv` |

### Open Questions
- [ ] Delete slides 11–14 from original presentation before the session
- [ ] Confirm whether the workshop uses the 4-slide copy or the updated original presentation
- [ ] Does the facilitator need the Colab notebook open during Slide 8 (to show case data tables live)?
- [ ] Is Treeplla client name safe to mention in the workshop, or should it stay anonymized as "a KR gaming client"?

---

## Session 2026-04-22 / 2026-04-23

### Context
- **Scope:** Slide 8 complication review; speaker notes refinement; search for US post-switch campaign results; HTML export fix; pronunciation and English coaching
- **Sources used:** Google Slides API, BQ Agent, Glean search, `GDS_Storytelling_Workshop_Facilitator_Guide.md`

### Process & Hypotheses

| Step | Question / Task | Approach | Finding |
|------|----------------|----------|---------|
| 1 | Did the updated slide 8 complication improve clarity? | Read slide via Slides API (ADC token after initial 403) | Yes — whale/minnow language added. Opening clause "US converter distribution is different from T2" is redundant; recommend dropping it (Option A) |
| 2 | Refine user's raw speaker notes for slide 8 | Manual refinement of user-provided script | Fixed 7 language issues; restructured data walkthrough → complication → resolution flow; dropped "LTV-based marker" from resolution |
| 3 | Did Treeplla ever launch a cumul_rev_7 US campaign? | Glean search → no results → BQ query on advertiser nBsHBgiHeOljDuHW post-June 2025 | **No cumul_rev_7 campaign exists.** Client moved to ROAS optimization for US after pausing m_rev_5 in June 2025 |
| 4 | Is there a campaign review deck with post-switch metrics? | Tried Slides API on `1WI-mp_LUuCXiXoAv9wtygyDzgerr7B60iGUstGmvV7U` | Permission denied — inaccessible |
| 5 | Fix HTML export — script sections rendering as wall of text | Diagnosed: pandoc collapsing blockquotes into `<p>` with literal `>` chars; rewrote with custom Python converter | Fixed — 19 script blocks properly rendered with line-by-line separation |

### Key Findings

1. **cumul_rev_7 was never launched as a US campaign event** — BQ query on advertiser `nBsHBgiHeOljDuHW`, all US campaigns post-June 2025: three campaigns found (`IAPROAS_250905`, `Hybrid_ROAS_251203` iOS + AOS), all ROAS-optimized. No CPA event campaign with any cumul_rev target exists. Implication: the workshop resolution ("switch to cumul_rev_7") describes a recommended approach that was never implemented — the actual outcome was a shift to ROAS optimization.

2. **Post-switch US strategy: ROAS, not threshold recalibration** — Treeplla US moved from event-triggered CPA (m_rev_5, $214.77 CPA) to Hybrid ROAS (af_ad_revenue + af_purchase). This sidesteps the whale/minnow threshold problem entirely. Implication: workshop resolution could be updated to reflect this, or kept as cumul_rev_7 for pedagogical clarity with a facilitator note about the actual outcome.

3. **Slide 8 complication — redundant opening clause** — Current text: "US converter distribution is different from that of T2; Only ~70% of US converters reach $5 by D7 vs. 90%+ in T2 — US users are either whales who blow past $5, or minnows who never reach it." The first clause weakens the punch. Option A (drop it): "Only ~70% of US converters reach $5 by D7 vs. 90%+ in T2 — US users split into whales who blow past $5 and minnows who never reach it." Decision pending.

4. **Facilitator guide script updated** — Refined slide 8 script committed to `GDS_Storytelling_Workshop_Facilitator_Guide.md`: fixed grammar ("campaigns have"), fixed "whale" spelling (×3), fixed "bimodal" (was "binomial"), removed LTV-based marker from resolution, added install-to-action curve as opening data point, stage directions updated.

### Open Questions
- [ ] **Complication box (slide 8):** Choose Option A (drop opening clause) or Option B (keep with "bimodal" reframe) — then update slide + guide + HTML
- [ ] **Resolution framing:** Keep cumul_rev_7 (pedagogical) or update to ROAS (reflects actual outcome)? Update slide + HTML after decision
- [ ] **Workshop intro:** Add Jamie credit line — preferred version: "Quick note before we dive in — the credit for this case goes to Jamie. I chose it because I think it's one of the best examples of data storytelling I've seen from our team. Thank you, Jamie." — not yet added to the guide
- [ ] **HTML not yet regenerated** — facilitator guide `.html` is behind the `.md` changes; regenerate after complication/resolution decisions are finalized
