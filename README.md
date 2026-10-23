> **A portfolio case study in SQL-based business analysis**
> Period under review: 1 July 2023 – 30 June 2025 (FY2024 vs FY2025)
> Role assumed: Junior Data Analyst, Sizwe Coffee (Pty) Ltd

---

## 1. The Brief — Why This Analysis Exists

Sizwe Coffee is a South African coffee roaster and wholesale distributor supplying roughly 1,400 business customers — grocers, restaurants, cafés, hotels, and offices — from distribution hubs in Johannesburg (Isando) and Cape Town (Epping). It sells through two routes: a traditional Wholesale channel and a recurring Subscription service.

As the company approached its year-end review, leadership had eight concrete questions they could not answer from their standard reports. They ranged from "which channel is actually growing?" to "why is our margin falling when revenue is up?" This repository is the complete answer to those questions: the SQL that produced every number, and the interpretation of what those numbers mean for the business.

**Headline numbers that frame everything that follows:**

| Metric | FY2024 | FY2025 | Change |
|---|---|---|---|
| Total revenue | R441m | R480m | +~9% |
| Gross margin | 34.7% | 33.0% | −1.7 pts |
| Sales reps on the road | 18 | 18 | — |

Revenue is up. Profitability per rand is down. That contradiction is the thread running through this whole project.

---

## 2. Analytical Approach

Every question in this project was answered in three stages:

1. **Locate the right tables.** Revenue lives in `sales_lines` (the item-level detail), not in `sales_orders` (the order header). Getting this distinction right is what makes the numbers reconcile to the company's reported totals.
2. **Define the time window.** The financial year runs July–June, so FY2024 = orders on or before 30 June 2024, and FY2025 = everything after that date.
3. **Aggregate, compare, and interpret.** Where a question asks for two years side by side, conditional aggregation (`SUM(CASE WHEN ...)`) puts both periods in one row. Where it asks for trends over time, window functions (`LAG`, rolling averages) reveal the shape of the year. Where it asks "who is missing out?", exclusion logic (`LEFT JOIN ... IS NULL`) surfaces the gaps.

The full technical toolkit used across the eight tasks:

- Date-range filtering and financial-year segmentation
- Inner and left joins across up to four tables per query
- Conditional aggregation for year-over-year comparison
- CTEs to stage intermediate results cleanly
- Window functions for month-on-month change and 3-month rolling averages
- Percentage, margin, and growth-rate calculations with controlled rounding
- Mix-shift decomposition to explain the margin decline

---

## 3. The Data

Eight source tables, joined on shared identifier columns. A quick orientation:

| Table | Grain | Why it matters here |
|---|---|---|
| `customers` | One row per account | Channel, segment, province, assigned rep, credit limit |
| `products` | One row per SKU | Product line classification, list price, unit cost |
| `sales_orders` | One row per order | Order/delivery dates, channel at time of sale, rep |
| `sales_lines` | One row per item in an order | **All revenue and cost figures originate here** |
| `ar_ledger` | One row per invoice | Amount, due date, settled amount, settlement date |
| `reps` | One row per salesperson | Territory and monthly revenue target |
| `rep_visits` | One row per customer visit | Field-activity records |
| `trade_promotions` | One row per promotion granted | Which customers received pricing support, on what |

A note on `channel`: it exists in both `customers` and `sales_orders`. Where the analysis is time-bound, the order-level channel was used, because it reflects the channel at the moment of each transaction rather than the customer's current classification.

---

## 4. Executive Summary of Findings

**Growth is real but uneven.** Both channels expanded year-on-year, and Wholesale — the larger of the two — contributed the bulk of the R39m revenue increase. Subscription grew proportionally faster from a smaller base.

**Profit is concentrated.** The product line that generates the most total gross profit is not the product line with the highest margin percentage. Volume and profitability per unit point in different directions, which matters for how the company should prioritise its product range.

**Cash is trapped in one channel.** Wholesale customers pay slower, carry the majority of outstanding invoices, and account for most of the unpaid balance. Subscription settles reliably and on time. Collections effort should be weighted toward Wholesale.

**A small number of accounts carry the business.** The top ten customers in FY2025 represent a disproportionate share of revenue. Losing any one of them would be material; growing them further is the highest-leverage sales activity available.

**Promotional support is misallocated.** Fifteen high-value Wholesale accounts — including the top three on that list — have never received a trade promotion. They are spending heavily with Sizwe while peers get support they may not need.

**Rep performance spans a wide range.** Some territories consistently exceed monthly targets; others produce little or no revenue. The gap is large enough to warrant territory review, coaching, or both.

**The year has a predictable shape.** Revenue peaks toward the end of the calendar year and dips consistently around mid-year (June/July). This pattern is stable across both years and should drive stock, staffing, and cash-flow planning.

**The margin drop is a mix story, not a pricing story.** No single product line became meaningfully less profitable. Instead, lower-margin lines grew faster and took up a larger share of total sales in FY2025. Because those lines keep less profit per rand, the company-wide average fell by 1.7 percentage points even as the top line grew.

---

## 5. Task-by-Task Coverage

| # | Business Question | Core SQL Technique |
|---|---|---|
| 1 | How did each channel perform in FY2024 vs FY2025? | Conditional aggregation, growth-rate calculation |
| 2 | Where does gross profit actually come from? | Multi-table join, profit & margin derivation |
| 3 | How serious is the collections problem? | Invoice ageing, days-to-settle, outstanding balance |
| 4 | Who are the ten accounts that matter most? | Ranked top-N with left join to preserve unassigned reps |
| 5 | Which high-value customers are being overlooked on promotions? | Anti-join / exclusion logic, top-N ranking |
| 6 | Are sales reps hitting their monthly targets? | Left join from reps, target-vs-actual comparison |
| 7 | What does the year look like month by month? | Window functions: LAG + rolling 3-month average |
| 8 | Why did margin fall when revenue rose? | Year-over-year mix decomposition per product line |

---

## 6. Recommendations to Leadership

Based on the findings above, four actions would move the needle most:

1. **Tighten Wholesale collections.** Because that channel holds most of the outstanding debt and pays slowest, even a modest improvement in average days-to-settle would meaningfully improve cash flow.
2. **Protect and grow the top ten accounts.** Assign named relationship owners, review their promotion eligibility, and flag any churn signal early.
3. **Extend promotions to the top three overlooked Wholesale accounts.** They are already high-spenders; structured support could lock in loyalty and unlock further volume.
4. **Address the product mix.** If margin recovery is a priority, the company should either grow higher-margin lines faster or review pricing on the lower-margin lines that are currently driving volume.



7. Reproducing the Analysis

**Environment:** PostgreSQL-compatible SQL (verified to run in Databricks SQL and DuckDB as well).

**Steps:**
1. Ensure all eight source tables are loaded and visible in your current schema — if a "table not found" error appears, check `current_schema()` and qualify table names with the correct catalog and schema.
2. Open `queries.sql`.
3. Run the eight statements in order, top to bottom. Each is self-contained and includes a comment block with the written interpretation of its result.
4. Revenue totals should reconcile to R441m (FY2024) and R480m (FY2025). If they do not, the financial-year date boundary is the first thing to check.

**Assumptions & limitations:**
- Analysis is query-only; no data was modified, inserted, or deleted.
- Where a result cell is `NULL`, it means no matching records exist for that combination.
- `channel` was taken from `sales_orders` for time-bound analysis, per the project brief's guidance.
- Reps with zero FY2025 revenue are retained in Task 6 via a left join, so
