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

print("Rows:", len(df))
print("Total revenue:", df["Revenue_EGP"].sum())
print("Total units:", df["Units"].sum())
print("Average order value:", round(df["Revenue_EGP"].mean(), 2))

print("\nRevenue by month:")
print(
    df.groupby(df["Date"].dt.to_period("M"))["Revenue_EGP"]
    .sum()
    .sort_index()
)

print("\nRevenue by category:")
print(df.groupby("Category")["Revenue_EGP"].sum().sort_values(ascending=False))

print("\nRevenue by city:")
print(df.groupby("City")["Revenue_EGP"].sum().sort_values(ascending=False))

print("\nTop products:")
print(df.groupby("Product")["Revenue_EGP"].sum().sort_values(ascending=False).head())