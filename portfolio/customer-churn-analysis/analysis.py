import pandas as pd

df = pd.read_csv("customer_data.csv")
df["Date"] = pd.to_datetime(df["Date"])

assert len(df) == 30
assert df.isna().sum().sum() == 0
assert (df["Revenue_EGP"] == df["Tenure_Months"] * df["Monthly_Fee_EGP"]).all()
assert df["Revenue_EGP"].sum() == 316230
assert df["Churned"].sum() == 10
assert round(df["Churned"].mean(), 4) == 0.3333

plan = df.groupby("Plan").agg(customers=("Churned","size"), churn_rate=("Churned","mean"), revenue=("Revenue_EGP","sum")).sort_values("churn_rate", ascending=False)
city = df.groupby("City").agg(customers=("Churned","size"), churn_rate=("Churned","mean")).sort_values("churn_rate", ascending=False)
channel = df.groupby("Channel").agg(customers=("Churned","size"), churn_rate=("Churned","mean")).sort_values("churn_rate", ascending=False)

print("Customers:", len(df))
print("Revenue:", df["Revenue_EGP"].sum())
print("Churned customers:", df["Churned"].sum())
print("Churn rate:", round(df["Churned"].mean() * 100, 2), "%")
print("\nChurn by plan:")
print(plan)
print("\nChurn by city:")
print(city)
print("\nChurn by channel:")
print(channel)
print("\nAll validation checks passed.")