# Repetitive Analysis Topics Project

## Objective
Identify repetitive analysis topics based on previous Jira tickets, investigation/analysis Google Docs from the **last 1 year** and compile resources + create investigation checklists.

## Status
- [x] Glean MCP server configured (`~/.cursor/mcp.json`) - **UPDATED to correct package**
- [ ] **Restart Cursor to activate Glean** (required after config change)
- [x] Review local SQL files for patterns
- [ ] Search and compile resources for remaining topics (blocked by Glean)
- [x] Draft Fraud Investigation checklist
- [x] Draft VT Analysis checklist

---

## Topics Overview

### Already Completed (Examples)
- **CPI Spike Analysis**
- **ROAS Performance Deep-dives**

Example resources:
- Spreadsheet: https://docs.google.com/spreadsheets/d/1fJkfkKenFDXCOeN2T-k_5bKQo4HJyLB3myFBDoDFlxM/edit?gid=0#gid=0
- Spreadsheet: https://docs.google.com/spreadsheets/d/1uX9k8NDg4JOpfJKREc6JdLrjhDenFwJkZ4nRdQBKWMo/edit?gid=0#gid=0
- Spreadsheet: https://docs.google.com/spreadsheets/d/1OjxVkpmoErw9ZYnFMJz1-h_rxJ-MM2FONuS0YF4AyKM/edit?gid=0#gid=0
- Investigation Checklist Doc: https://docs.google.com/document/d/1gNXW1SCEIlcTNCTEhZS7AOD2FgfYgyEeMLH-Icvkjg8/edit?tab=t.0
- Investigation Checklist Doc: https://docs.google.com/document/d/1vZCrMoZz7vfX5ShkLuJRJ_ERuIu1DVMfb4wR0pAjkNA/edit?tab=t.0

### Topics To Do

| Topic | Status | Glean Search Queries |
|-------|--------|---------------------|
| **Fraud Investigations** | Pending | `fraud investigation`, `fraud analysis`, `suspicious publisher`, `invalid traffic`, `fraud detection` |
| **VT Analysis** | Pending | `VT analysis`, `view-through`, `VT performance`, `VT attribution`, `VT vs SKAN` |
| **Publisher-specific Analysis** | Pending | `publisher analysis`, `publisher performance`, `supply analysis`, `publisher investigation` |
| **RE Test Analysis** | Pending | `RE test`, `retargeting experiment`, `RE analysis`, `remarketing test`, `RE performance` |

---

## Deliverables for Each Topic

### 1. Google Spreadsheet with Links
Columns to include:
- Resource Name/Title
- Type (Jira ticket, Google Doc, Slides, etc.)
- Link
- Date
- Summary/Description
- Key Findings (if applicable)

### 2. Google Doc - Investigation Checklist
Sections to include:
- Overview / When to use this checklist
- Prerequisites / Data sources needed
- Step-by-step investigation process
- Key metrics to check
- Common patterns / Red flags
- Example queries (SQL)
- Example cases with findings
- Escalation criteria

---

## Glean Configuration

Location: `~/.cursor/mcp.json`

```json
{
  "mcpServers": {
    "glean": {
      "command": "npx",
      "args": [
        "-y",
        "@gleanwork/local-mcp-server",
        "--instance",
        "moloco-be",
        "--token",
        "<YOUR_GLEAN_API_TOKEN>"
      ]
    }
  }
}
```

**Package:** `@gleanwork/local-mcp-server` (v0.9.1)
**Documentation:** https://github.com/gleanwork/mcp-server

---

## Next Steps
1. **Restart Cursor** to activate Glean MCP server
2. Use Glean to search for each topic using the queries above
3. Compile results into spreadsheets (one per topic)
4. Create investigation checklist docs (one per topic)
5. Cross-reference with existing SQL queries in this repo:
   - `Fraud/` folder - existing fraud-related queries
   - `iOS Measurement/` folder - VT analysis queries
   - `Campaign investigation/` folder - publisher analysis
   - `RE activation/` folder - RE test related queries

---

## Related Local Files

### Fraud Investigation
- `Fraud/publisher_performance_data.sql`
- `Fraud/ODSB-15998 Suspected Publisher and IDFA`
- `Fraud/odsb14358_fraud_user_analysis`

### VT Analysis
- `iOS Measurement/VT_vs_SKAN_Performance_Analysis.ipynb`
- `iOS Measurement/SKAN_performance_vt_install.sql`
- Various VT-related PNG charts in `iOS Measurement/`

### Publisher-specific Analysis
- `Campaign investigation/publishers_by_cr_format.sql`
- `BQ_Tables/BQ_Aggregated/table_fact_dsp_publisher.sql`

### RE Test Analysis
- `RE activation/` folder
- `Campaign investigation/RE_static_target_user_check.sql`
- `Tmp/RE audience leakage.sql`
- `Tmp/re_audience_size.sql`

---

*Last updated: Feb 3, 2026*
