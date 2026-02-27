# ODSB-15998: ITCT Analysis for Suspicious MTIDs

**Jira:** [https://mlc.atlassian.net/browse/ODSB-15998](https://mlc.atlassian.net/browse/ODSB-15998)

**Date:** 2026-02-06

---

## Objective

Analyze Impression-to-Click Time (ITCT) patterns for MTIDs with 30+ clicks to identify if abnormal click behaviors originate from specific IP addresses.

## Background

- Certain MTIDs (single impressions) are generating 30+ clicks, which is highly abnormal
- Need to investigate if this click fraud pattern is associated with specific IPs or IP ranges
- Related to suspected publisher/IDFA analysis

## Key Questions

1. What is the ITCT distribution for suspicious MTIDs (30+ clicks)?
2. Are these abnormal clicks coming from specific IP addresses?
3. Is there an IP concentration pattern among fraudulent clicks?

## Data Sources

- `focal-elf-631.prod_stream_view.cv` - Conversion events
- `focal-elf-631.prod_stream_view.click_surplus` - Click surplus data with IP info

## Key Fields

- `req.device.ip` - IP address
- `req.device.ifa` - IDFA
- `bid.mtid` - MTID (impression identifier)
- `imp.received_at` - Impression timestamp
- `click.received_at` - Click timestamp
- `click_surplus.reason` - Click surplus reason

## Files


| File                             | Description            |
| -------------------------------- | ---------------------- |
| `ODSB-15998_ITCT_analysis.ipynb` | ITCT analysis notebook |


---

## Reference Docs

- Analysis Doc: [https://docs.google.com/document/d/13HJNqPWySES-zGBTObV8J64zFN6k1UVPDFLsC3BOt54](https://docs.google.com/document/d/13HJNqPWySES-zGBTObV8J64zFN6k1UVPDFLsC3BOt54)
- Data Sheet: [https://docs.google.com/spreadsheets/d/1bxC9NePBJDzHAbZTX1JYd1wPmGL2BT0SLaHmJjIhR6I](https://docs.google.com/spreadsheets/d/1bxC9NePBJDzHAbZTX1JYd1wPmGL2BT0SLaHmJjIhR6I)

