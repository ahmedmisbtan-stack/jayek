import pandas as pd

df = pd.read_csv("sales_data.csv")
df["Date"] = pd.to_datetime(df["Date"])

print("Rows:", len(df))
print("Total revenue:", df["Revenue_EGP"].sum())
print("Total units:", df["Units"].sum())
print("Average order value:", round(df["Revenue_EGP"].mean(), 2))

print("\nRevenue by category:")
print(df.groupby("Category")["Revenue_EGP"].sum().sort_values(ascending=False))

print("\nRevenue by city:")
print(df.groupby("City")["Revenue_EGP"].sum().sort_values(ascending=False))

print("\nTop products:")
print(df.groupby("Product")["Revenue_EGP"].sum().sort_values(ascending=False).head())