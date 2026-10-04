-- Beginner SQL analysis
SELECT COUNT(*) AS orders, SUM(Revenue_EGP) AS total_revenue,
       SUM(Units) AS total_units, AVG(Revenue_EGP) AS average_order_value
FROM sales_data;

SELECT strftime('%Y-%m', Date) AS month,
       SUM(Revenue_EGP) AS revenue
FROM sales_data
GROUP BY strftime('%Y-%m', Date)
ORDER BY month;

SELECT Category, SUM(Revenue_EGP) AS revenue
FROM sales_data
GROUP BY Category
ORDER BY revenue DESC;

SELECT City, SUM(Revenue_EGP) AS revenue
FROM sales_data
GROUP BY City
ORDER BY revenue DESC;

SELECT Product, SUM(Revenue_EGP) AS revenue
FROM sales_data
GROUP BY Product
ORDER BY revenue DESC;