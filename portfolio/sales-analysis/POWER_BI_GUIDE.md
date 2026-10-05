# Power BI - Beginner Dashboard

## Goal

Build a simple one-page sales dashboard from `sales_data.csv`.

This is a learning project using 25 synthetic sales records from January to March 2026.

## 1. Import

Power BI Desktop -> Get Data -> Text/CSV -> `sales_data.csv`.

Set:
- `Date` = Date
- `City`, `Category`, `Product` = Text
- `Units` = Whole number
- `Unit_Price_EGP`, `Revenue_EGP` = Decimal number / Fixed decimal as appropriate

## 2. Data checks

Before building visuals, confirm:
- Rows = 25
- Total Revenue = 80,270 EGP
- Total Units = 247
- Orders = 25
- Average Order Value = 3,210.80 EGP
- Revenue = Units * Unit_Price_EGP for every row

## 3. DAX measures

```DAX
Total Revenue = SUM(sales_data[Revenue_EGP])

Total Units = SUM(sales_data[Units])

Orders = COUNTROWS(sales_data)

Average Order Value = DIVIDE([Total Revenue], [Orders])

Revenue by Order = [Total Revenue] / [Orders]
```

Format `Total Revenue`, `Average Order Value`, and `Revenue by Order` as EGP.

## 4. Recommended one-page layout

### Top row - KPI cards
1. Total Revenue
2. Orders
3. Total Units
4. Average Order Value

### Middle row
- Line/column chart: Revenue by Month
- Bar chart: Revenue by Category

### Bottom row
- Bar chart: Revenue by City
- Bar chart: Top 5 Products

### Slicer
Add a Date slicer so the dashboard can be filtered by period.

## 5. Expected results

### Monthly Revenue
- January 2026: 26,520 EGP
- February 2026: 27,520 EGP
- March 2026: 26,230 EGP

### Category Revenue
- Electronics: 50,410 EGP
- Home: 17,200 EGP
- Office: 12,660 EGP

### City Revenue
- Cairo: 32,910 EGP
- Giza: 28,110 EGP
- Qalyubia: 19,250 EGP

### Top Products
Sort products by Total Revenue descending and show the top 5.

## 6. Design rules

- Keep the report to one page.
- Use a clear title: **Sales Analysis Dashboard**.
- Use consistent EGP formatting.
- Sort revenue charts from highest to lowest where appropriate.
- Keep labels readable on mobile-sized screens.
- Avoid unnecessary 3D charts and decorative visuals.
- Add a small footer: **Practice dataset - not real company data**.

## 7. Portfolio validation

The dashboard is ready when:
- Every KPI matches the CSV.
- Category totals match the expected results above.
- Monthly totals match the expected results above.
- City totals match the expected results above.
- Filters change the visuals correctly.
- No visual shows blank or incorrect values.

> The repository currently contains a reference dashboard layout, not a native Power BI `.pbix` file. A `.pbix` file requires Power BI Desktop to create/save.
