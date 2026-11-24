-- Pizza restaurant sales analysis
-- Tables: orders, order_details, pizzas, pizza_types
-- month, hour and weekday columns were added to orders in Python before loading.

-- 1. Overall numbers
SELECT COUNT(DISTINCT od.order_id)                                   AS total_orders,
       SUM(od.quantity)                                              AS pizzas_sold,
       ROUND(SUM(od.quantity * p.price))                             AS revenue,
       ROUND(SUM(od.quantity * p.price) / COUNT(DISTINCT od.order_id), 2) AS avg_order_value,
       ROUND(1.0 * SUM(od.quantity) / COUNT(DISTINCT od.order_id), 2) AS pizzas_per_order
FROM order_details od
JOIN pizzas p ON od.pizza_id = p.pizza_id;

-- 2. Revenue by month, and change from last month (LAG)
WITH monthly AS (
    SELECT o.month,
           SUM(od.quantity * p.price) AS revenue
    FROM orders o
    JOIN order_details od ON o.order_id = od.order_id
    JOIN pizzas p         ON od.pizza_id = p.pizza_id
    GROUP BY o.month
)
SELECT month,
       ROUND(revenue) AS revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
             / LAG(revenue) OVER (ORDER BY month), 1) AS change_pct
FROM monthly
ORDER BY month;

-- 3. Busiest hours of the day
SELECT hour,
       COUNT(*) AS orders
FROM orders
GROUP BY hour
ORDER BY hour;

-- 4. Busiest days of the week
SELECT weekday,
       COUNT(*)                                    AS orders,
       ROUND(1.0 * COUNT(*) / COUNT(DISTINCT date), 1) AS avg_orders_per_day
FROM orders
GROUP BY weekday
ORDER BY avg_orders_per_day DESC;

-- 5. Sales by pizza category, with share of total (CTE + subquery)
WITH category_sales AS (
    SELECT t.category,
           SUM(od.quantity)            AS pizzas_sold,
           SUM(od.quantity * p.price)  AS revenue
    FROM order_details od
    JOIN pizzas p       ON od.pizza_id = p.pizza_id
    JOIN pizza_types t  ON p.pizza_type_id = t.pizza_type_id
    GROUP BY t.category
)
SELECT category,
       pizzas_sold,
       ROUND(revenue) AS revenue,
       ROUND(100.0 * revenue / (SELECT SUM(revenue) FROM category_sales), 1) AS revenue_share_pct
FROM category_sales
ORDER BY revenue DESC;

-- 6. Sales by pizza size
SELECT p.size,
       SUM(od.quantity)                  AS pizzas_sold,
       ROUND(SUM(od.quantity * p.price)) AS revenue
FROM order_details od
JOIN pizzas p ON od.pizza_id = p.pizza_id
GROUP BY p.size
ORDER BY revenue DESC;

-- 7. Top 3 pizzas in each category (ROW_NUMBER)
WITH pizza_sales AS (
    SELECT t.category,
           t.name,
           ROUND(SUM(od.quantity * p.price)) AS revenue
    FROM order_details od
    JOIN pizzas p       ON od.pizza_id = p.pizza_id
    JOIN pizza_types t  ON p.pizza_type_id = t.pizza_type_id
    GROUP BY t.category, t.name
),
ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY category ORDER BY revenue DESC) AS rank_in_category
    FROM pizza_sales
)
SELECT category, rank_in_category, name, revenue
FROM ranked
WHERE rank_in_category <= 3
ORDER BY category, rank_in_category;

-- 8. Bottom 5 pizzas by revenue
SELECT t.name,
       SUM(od.quantity)                  AS pizzas_sold,
       ROUND(SUM(od.quantity * p.price)) AS revenue
FROM order_details od
JOIN pizzas p       ON od.pizza_id = p.pizza_id
JOIN pizza_types t  ON p.pizza_type_id = t.pizza_type_id
GROUP BY t.name
ORDER BY revenue ASC
LIMIT 5;

-- 9. How many pizza types sell less than the average? (subquery)
WITH pizza_qty AS (
    SELECT t.name, SUM(od.quantity) AS pizzas_sold
    FROM order_details od
    JOIN pizzas p       ON od.pizza_id = p.pizza_id
    JOIN pizza_types t  ON p.pizza_type_id = t.pizza_type_id
    GROUP BY t.name
)
SELECT COUNT(*) AS pizza_types_below_average,
       (SELECT COUNT(*) FROM pizza_qty) AS total_pizza_types
FROM pizza_qty
WHERE pizzas_sold < (SELECT AVG(pizzas_sold) FROM pizza_qty);

-- 10. How many pizzas do people buy in one order? (CASE)
WITH order_size AS (
    SELECT order_id, SUM(quantity) AS pizzas
    FROM order_details
    GROUP BY order_id
)
SELECT CASE WHEN pizzas = 1 THEN '1 pizza'
            WHEN pizzas = 2 THEN '2 pizzas'
            WHEN pizzas <= 4 THEN '3-4 pizzas'
            ELSE '5 or more'
       END      AS order_size,
       COUNT(*) AS orders
FROM order_size
GROUP BY order_size
ORDER BY MIN(pizzas);

