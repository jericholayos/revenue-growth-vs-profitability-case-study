set search_path to retail;

-------------------------
-- Business Questions:
-------------------------
-- Is the business growing month over month, and by how much?
-- What are the best and worst performing products within each category?
-- Who are our most valuable customers, and how concentrated is revenue among them?
-- At what discount level does profit turn negative?
-- Which regions have total revenue below the average revenue across all regions?
-- Which product subcategories have the highest return rates, and what is the associated profit loss?
-- Which product categories and subcategories generate high sales but low profit margins?
-- Which sales segments or shipping modes contribute the most to revenue and profit?

SELECT
	*
FROM fact_sales
LIMIT 5;



--------------------
-- Summary 
--------------------
SELECT
	SUM(sales) AS total_revenue,
	SUM(profit) AS total_profit,
	COUNT(DISTINCT customer_id) AS total_customers,
	ROUND(SUM(profit) / SUM(sales) * 100.0, 2) AS profit_margin,
	COUNT(DISTINCT order_id) AS total_orders,
	ROUND(SUM(sales) / COUNT(DISTINCT order_id), 2) AS avg_order_value,
	ROUND(COUNT(DISTINCT CASE WHEN returned = 'Yes' THEN order_id END)::DECIMAL / COUNT(DISTINCT order_id) * 100.0, 2) AS return_rate
FROM fact_sales;

SELECT
	MIN(order_date) AS min_date, --		Starts on January 1 2023
	MAX(order_date) AS max_date -- 		Ends on December 30 2026
FROM fact_sales;

------------------------------
-- Analytical Queries:
------------------------------

-- Is the business growing month over month, and by how much?
WITH current_sales AS (
SELECT
	DATE_TRUNC('month', order_date)::DATE AS month,
	SUM(sales) AS revenue,
	SUM(profit) AS profit
FROM fact_sales
GROUP BY 1
),
previous_sales AS (
SELECT
	month,
	revenue,
	LAG(revenue) OVER(ORDER BY month) AS previous_revenue,
	profit,
	LAG(profit) OVER(ORDER BY month) AS previous_profit
FROM current_sales
)
SELECT
	month AS "Month",
	ROUND((revenue - previous_revenue) * 100.0 / NULLIF(previous_revenue, 0), 2) AS "Revenue MoM (%)",
	ROUND((profit - previous_profit) * 100.0 / NULLIF(previous_profit, 0), 2) AS "Profit MoM (%)"
FROM previous_sales;


-- What are the best and worst performing products within each category?
WITH rank_sales AS (
SELECT
	product_name,
	category,
	SUM(sales) AS total_revenue,
	ROW_NUMBER() OVER(PARTITION BY category ORDER BY SUM(sales) DESC) AS rnk_desc,
	ROW_NUMBER() OVER(PARTITION BY category ORDER BY SUM(sales) ASC) AS rnk_asc
FROM fact_sales s
INNER JOIN dim_product p 
	ON s.product_id = p.product_id
GROUP BY product_name, category
)
SELECT
	product_name,
	category,
	total_revenue,
	CASE
		WHEN rnk_desc = 1 THEN 'Best'
		WHEN rnk_asc = 1 THEN 'Worst'
 	END AS performance
FROM rank_sales
WHERE rnk_desc = 1
	OR rnk_asc = 1
ORDER BY 3 DESC;

-- Which segment is most valuable, and how concentrated is revenue among them?
SELECT 
	segment,
	SUM(s.sales) AS total_revenue,
	COUNT(DISTINCT c.customer_id) AS total_customers,
	ROUND(SUM(sales) / SUM(SUM(sales)) OVER() * 100.0, 1) AS pct_of_total
FROM dim_customer c
INNER JOIN fact_sales s
	ON c.customer_id = s.customer_id
GROUP BY segment;

-- Who are our most valuable customers?
WITH rank_customers AS (
SELECT
	customer_name,
	region,
	SUM(sales) AS total_revenue,
	ROW_NUMBER() OVER(PARTITION BY region ORDER BY SUM(sales) DESC) AS rn
FROM fact_sales s
INNER JOIN dim_customer c
	ON s.customer_id = c.customer_id
GROUP BY 1, 2
)
SELECT
	customer_name,
	region,
	total_revenue,
	ROUND(total_revenue / SUM(total_revenue) OVER() * 100.0, 2) pct_of_revenue
FROM rank_customers
WHERE rn <= 3;

-- At what discount level does profit turn negative?
SELECT
	ROUND(discount * 100.0, 1) AS "Discount (%)",
	SUM(profit) AS "Total Profit",	
	ROUND(AVG(profit), 2) AS "Avg Profit Per Order",
	COUNT(*) AS "Total Orders"
FROM fact_sales
GROUP BY 1
HAVING SUM(profit) < 0
ORDER BY 2 ASC;

-- Which regions have total revenue below the average revenue across all regions?
WITH region_sales AS (
SELECT
	region,
	SUM(sales) AS total_revenue
FROM fact_sales
GROUP BY 1
),
company_avg AS (
SELECT
	ROUND(AVG(total_revenue), 2) AS company_avg -- 581633.63
FROM region_sales
)
SELECT
	region,
	total_revenue
FROM region_sales
CROSS JOIN company_avg
WHERE total_revenue < company_avg;

-- Which product subcategories have the highest return rates, and what is the associated profit loss?
WITH cte AS (
SELECT
	sub_category,
	COUNT(DISTINCT CASE WHEN returned = 'Yes' THEN order_id END) AS return_count,
	COUNT(DISTINCT order_id) AS total_orders,
	SUM(CASE WHEN returned = 'Yes' THEN profit ELSE 0 END) AS total_profit
FROM fact_sales s
INNER JOIN dim_product p
	ON p.product_id = s.product_id
GROUP BY 1
)
SELECT
	sub_category,
	ROUND(return_count::decimal / total_orders::decimal * 100.0, 2) AS return_rate,
	total_profit
FROM cte
ORDER BY 2 DESC;

-- Which product categories and subcategories generate high sales but low profit margins?
WITH CTE AS (
SELECT
	category,
	sub_category,
	ROUND(SUM(sales), 2) AS total_revenue,
	ROUND(SUM(profit) / SUM(sales) * 100.0, 2) AS profit_margin
FROM fact_sales s
INNER JOIN dim_product p
	ON s.product_id = p.product_id
GROUP BY 1, 2
),
CTE2 AS (
SELECT
	AVG(total_revenue) AS avg_revenue
FROM cte
)
SELECT
	category,
	sub_category,
	total_revenue,
	profit_margin
FROM CTE
CROSS JOIN CTE2
WHERE total_revenue > avg_revenue
ORDER BY profit_margin ASC, total_revenue DESC;

-- Which sales segments or shipping modes contribute the most to revenue and profit?
SELECT
	ship_mode,
	SUM(sales) AS total_revenue,
	SUM(profit) AS total_profit,
	ROUND(SUM(sales) / SUM(SUM(sales)) OVER() * 100.0, 2)AS pct_of_revenue
FROM fact_sales
GROUP BY 1
ORDER BY 3 DESC;








