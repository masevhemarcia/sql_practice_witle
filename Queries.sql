         ---Task 1: Channel performance-----

SELECT
    so.channel,
    SUM(CASE WHEN so.order_date <= '2024-06-30' THEN sl.line_revenue END) AS fy2024_revenue,
    SUM(CASE WHEN so.order_date > '2024-06-30' THEN sl.line_revenue END) AS fy2025_revenue,
    ROUND(
      (SUM(CASE WHEN so.order_date > '2024-06-30' THEN sl.line_revenue END) -
       SUM(CASE WHEN so.order_date <= '2024-06-30' THEN sl.line_revenue END)) /
       SUM(CASE WHEN so.order_date <= '2024-06-30' THEN sl.line_revenue END) * 100,
      2
    ) AS growth_pct
FROM sizwe_sales_orders so
JOIN sizwe_sales_lines sl ON so.order_id = sl.order_id
GROUP BY so.channel;

/*Answer: Wholesale is the biggest channel, while Subscription also grew slightly different from wholesale by 0,01 .*/


 ---Task 2: Where the profit actually comes from----


SELECT
    p.product_line,
    SUM(sl.line_revenue) AS total_revenue,
   SUM(sl.cogs) AS total_cogs,
     SUM(sl.line_revenue) - SUM(sl.cogs) AS gross_profit,

    ROUND(
     (SUM(sl.line_revenue) - SUM(sl.cogs)) / SUM(sl.line_revenue) * 100,
      2
    ) AS gross_margin_pct
FROM sizwe_sales_lines sl
JOIN sizwe_products p ON sl.sku = p.sku
GROUP BY p.product_line
ORDER BY gross_profit DESC;
/*Answer:
 House blend earns the most profitand it is not the same line that earned the highest margin,the line that earned the highest margin is Single origin product_line */

\


------Task 3: The collections problem--------

SELECT
    c.channel,
    COUNT(*) AS total_invoices,
    COUNT(CASE WHEN al.amount_settled >= al.invoice_amount THEN 1 END) AS settled_count,
    COUNT(CASE WHEN al.amount_settled < al.invoice_amount THEN 1 END) AS open_count,
    ROUND(
      AVG(CASE 
          WHEN al.settlement_date IS NOT NULL 
          THEN EXTRACT(DAY FROM al.settlement_date - al.due_date) 
          END),
      1
    ) AS avg_days_to_settle,
    SUM(al.invoice_amount - al.amount_settled) AS total_outstanding
FROM sizwe_ar_ledger al
JOIN sizwe_customers c 
  ON al.customer_id = c.customer_id
GROUP BY c.channel;

 --Answer:
--One channel is paying noticeably slower and holds most of the outstanding debt.
-- Focus on that channel first — it carries the biggest cash-flow risk.


----- Task 4: The ten accounts that matter most-------

SELECT
    c.trading_name,
    c.segment,
    c.province,
    r.rep_name,
    ROUND(SUM(sl.line_revenue), 2) AS fy2025_revenue
FROM sizwe_customers c
JOIN sizwe_sales_orders so 
  ON c.customer_id = so.customer_id
JOIN sizwe_sales_lines sl 
  ON so.order_id = sl.order_id
LEFT JOIN sizwe_reps r 
  ON c.rep_id = r.rep_id
WHERE so.order_date > '2024-06-30'
GROUP BY c.trading_name, c.segment, c.province, r.rep_name
ORDER BY fy2025_revenue DESC
LIMIT 10;

-- Answer:
-- These 10 customers make up a large share of FY2025 revenue.
-- Keeping them happy is the #1 priority to protect income.


 -- Task 5: A commercial gap------

WITH promoted AS (
    SELECT DISTINCT customer_id FROM sizwe_trade_promotions
)
SELECT
    c.trading_name,
    c.segment,
    c.province,
   round (SUM(sl.line_revenue),2) AS fy2025_revenue
FROM sizwe_customers c
JOIN sizwe_sales_orders so 
  ON c.customer_id = so.customer_id
JOIN sizwe_sales_lines sl 
  ON so.order_id = sl.order_id
LEFT JOIN promoted p 
  ON c.customer_id = p.customer_id
WHERE c.channel = 'Wholesale'
  AND p.customer_id IS NULL
  AND so.order_date > '2024-06-30'
GROUP BY c.trading_name, c.segment, c.province
ORDER BY fy2025_revenue DESC
LIMIT 15;

---- Answer:
---I would recommend having a support package for the top 3,since it shows them spending aslot and not receiving nything as a form of dupprot from sizwe 
group.


------ Task 6: Are the sales representatives hitting target?-----

SELECT
    r.rep_name,
    r.territory,
    r.target_monthly,
    ROUND(COALESCE(SUM(sl.line_revenue), 0) / 12, 2) AS avg_monthly_actual,
    ROUND(COALESCE(SUM(sl.line_revenue), 0) / 12 / r.target_monthly * 100,
      1) AS pct_of_target
FROM sizwe_reps r
LEFT JOIN sizwe_sales_orders so 
ON r.rep_id = so.rep_id 
 AND so.order_date > '2024-06-30'
LEFT JOIN sizwe_sales_lines sl 
  ON so.order_id = sl.order_id
GROUP BY r.rep_name, r.territory, r.target_monthly
ORDER BY pct_of_target DESC;

/* Answer:
Performance varies some reps exceed target while others produce nothing.The lowest performers need more training into performing better in the next FY.*/


---- Task 7: The shape of the year---

WITH monthly AS (
    SELECT
        DATE_TRUNC('month', so.order_date) AS month,
        SUM(sl.line_revenue) AS monthly_revenue
    FROM sizwe_sales_orders so
    JOIN sizwe_sales_lines sl ON so.order_id = sl.order_id
    GROUP BY DATE_TRUNC('month', so.order_date)
)
SELECT
    month,
    monthly_revenue,
    ROUND(
      (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY month)) 
        / LAG(monthly_revenue) OVER (ORDER BY month) * 100,
      1
    ) AS mom_pct_change,
    ROUND(
      AVG(monthly_revenue) OVER (
        ORDER BY month 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
      ), 
      2
    ) AS rolling_3month_avg
FROM monthly
ORDER BY month;

-- Answer:
-- There is a clear seasonal pattern — revenue peaks toward year-end.
-- The quietest month is consistently mid-year (usually June or July).


-- Task 8: Why has the margin moved?--

WITH yearly AS (
    SELECT
        p.product_line,
        CASE 
          WHEN so.order_date <= '2024-06-30' THEN 'FY2024'
          ELSE 'FY2025' 
        END AS financial_year,
        SUM(sl.line_revenue) AS line_revenue,
        SUM(sl.line_revenue) - SUM(sl.cogs) AS line_profit
    FROM sizwe_sales_lines sl
    JOIN sizwe_products p ON sl.sku = p.sku
    JOIN sizwe_sales_orders so ON sl.order_id = so.order_id
    GROUP BY p.product_line, 
             CASE 
               WHEN so.order_date <= '2024-06-30' THEN 'FY2024' 
               ELSE 'FY2025' 
             END
),
totals AS (
    SELECT financial_year, SUM(line_revenue) AS total_revenue 
    FROM yearly 
    GROUP BY financial_year
)
SELECT
    y.product_line,
    y.financial_year,
    y.line_revenue,
    ROUND(y.line_profit / y.line_revenue * 100, 1) AS line_margin_pct,
    ROUND(y.line_revenue / t.total_revenue * 100, 1) AS revenue_share_pct
FROM yearly y
JOIN totals t ON y.financial_year = t.financial_year
ORDER BY y.product_line, y.financial_year;

-- Answer:
-- Margin fell not because any single line became less profitable, but from mix shift.
-- Lower-margin lines grew faster and made up a larger share of total revenue in FY2025, pulling the overall average down.
