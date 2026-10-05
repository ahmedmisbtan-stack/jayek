import pandas as pd

df = pd.read_csv("sales_data.csv")
df["Date"] = pd.to_datetime(df["Date"])

# Basic data-integrity checks
assert len(df) == 25, f"Expected 25 rows, found {len(df)}"
assert df.isna().sum().sum() == 0, "Dataset contains missing values"

calculated_revenue = df["Units"] * df["Unit_Price_EGP"]
assert (calculated_revenue == df["Revenue_EGP"]).all(), (
    "Revenue mismatch: Units * Unit_Price_EGP must equal Revenue_EGP"
)

# Portfolio validation checks
assert df["Revenue_EGP"].sum() == 80270
assert df["Units"].sum() == 247
assert round(df["Revenue_EGP"].mean(), 2) == 3210.80

monthly = df.groupby(df["Date"].dt.to_period("M"))["Revenue_EGP"].sum().sort_index()
assert monthly.to_dict() == {
    pd.Period("2026-01"): 26520,
    pd.Period("2026-02"): 27520,
    pd.Period("2026-03"): 26230,
}

category = df.groupby("Category")["Revenue_EGP"].sum().sort_values(ascending=False)
assert category.to_dict() == {
    "Electronics": 50410,
    "Home": 17200,
    "Office": 12660,
}

city = df.groupby("City")["Revenue_EGP"].sum().sort_values(ascending=False)
assert city.to_dict() == {
    "Cairo": 32910,
    "Giza": 28110,
    "Qalyubia": 19250,
}

print("Rows:", len(df))
print("Total revenue:", df["Revenue_EGP"].sum())
print("Total units:", df["Units"].sum())
print("Average order value:", round(df["Revenue_EGP"].mean(), 2))

print("\nRevenue by month:")
print(monthly)

print("\nRevenue by category:")
print(category)

print("\nRevenue by city:")
print(city)

print("\nTop products:")
print(df.groupby("Product")["Revenue_EGP"].sum().sort_values(ascending=False).head())

print("\nAll validation checks passed.")