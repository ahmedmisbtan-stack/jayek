# Power BI - Beginner Dashboard

## Import
Power BI Desktop -> Get Data -> Text/CSV -> sales_data.csv

## Visuals
- Total Revenue (Card)
- Total Units (Card)
- Orders (Card)
- Average Order Value (Card)
- Revenue by Category
- Revenue by City
- Revenue by Product
- Revenue by Month

## DAX
```DAX
Total Revenue = SUM(sales_data[Revenue_EGP])
Total Units = SUM(sales_data[Units])
Orders = COUNTROWS(sales_data)
Average Order Value = DIVIDE([Total Revenue], [Orders])
```

This dashboard is intentionally simple because it is a beginner portfolio project.