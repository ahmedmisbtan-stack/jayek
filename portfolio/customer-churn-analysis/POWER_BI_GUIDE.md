# Power BI - Customer Churn Dashboard

## Import
Power BI Desktop -> Get Data -> Text/CSV -> customer_data.csv.

Set Date as Date, City/Plan/Channel as Text, Tenure_Months/Monthly_Fee_EGP/Revenue_EGP as numeric, and Churned as Whole number.

## DAX
```DAX
Customers = COUNTROWS(customer_data)
Revenue = SUM(customer_data[Revenue_EGP])
Churned Customers = SUM(customer_data[Churned])
Churn Rate = DIVIDE([Churned Customers], [Customers])
```

Format Churn Rate as Percentage and Revenue as EGP.

## One-page layout
Top: Customers | Revenue | Churned Customers | Churn Rate

Middle: Churn Rate by Plan | Churn Rate by City

Bottom: Churn Rate by Channel | Revenue by Plan

Slicers: Date, Plan, City, Channel.

## Expected checks
- Customers: 30
- Revenue: 316,230 EGP
- Churned Customers: 10
- Churn Rate: 33.33%
- Basic churn: 61.54%
- Qalyubia churn: 66.67%
- Mobile churn: 46.67%
- Web churn: 20.00%

Keep the report descriptive. Do not label these results as a predictive churn model.
