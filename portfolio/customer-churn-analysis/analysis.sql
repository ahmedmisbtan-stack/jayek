-- Customer churn analysis
SELECT COUNT(*) AS customers,
       SUM(Revenue_EGP) AS total_revenue,
       SUM(Churned) AS churned_customers,
       AVG(Churned) AS churn_rate
FROM customer_data;

SELECT Plan, COUNT(*) AS customers,
       SUM(Churned) AS churned_customers,
       AVG(Churned) AS churn_rate,
       SUM(Revenue_EGP) AS revenue
FROM customer_data
GROUP BY Plan
ORDER BY churn_rate DESC;

SELECT City, COUNT(*) AS customers,
       SUM(Churned) AS churned_customers,
       AVG(Churned) AS churn_rate
FROM customer_data
GROUP BY City
ORDER BY churn_rate DESC;

SELECT Channel, COUNT(*) AS customers,
       SUM(Churned) AS churned_customers,
       AVG(Churned) AS churn_rate
FROM customer_data
GROUP BY Channel
ORDER BY churn_rate DESC;