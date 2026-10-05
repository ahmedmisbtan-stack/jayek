from pathlib import Path
import csv
from collections import defaultdict
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.enum.text import PP_ALIGN
from pptx.dml.color import RGBColor

BASE = Path(__file__).parent
DATA = BASE / "sales_data.csv"
OUT = BASE / "sales_analysis_portfolio.pptx"

rows = []
with DATA.open(newline="", encoding="utf-8") as f:
    for row in csv.DictReader(f):
        row["Units"] = int(row["Units"])
        row["Unit_Price_EGP"] = float(row["Unit_Price_EGP"])
        row["Revenue_EGP"] = float(row["Revenue_EGP"])
        rows.append(row)

assert len(rows) == 25, f"Expected 25 rows, found {len(rows)}"
assert all(abs(r["Units"] * r["Unit_Price_EGP"] - r["Revenue_EGP"]) < 0.01 for r in rows), "Revenue mismatch"

total_revenue = sum(r["Revenue_EGP"] for r in rows)
total_units = sum(r["Units"] for r in rows)
orders = len(rows)
avg_order = total_revenue / orders

by_month = defaultdict(float)
by_category = defaultdict(float)
by_city = defaultdict(float)
by_product = defaultdict(float)
for r in rows:
    by_month[r["Date"][:7]] += r["Revenue_EGP"]
    by_category[r["Category"]] += r["Revenue_EGP"]
    by_city[r["City"]] += r["Revenue_EGP"]
    by_product[r["Product"]] += r["Revenue_EGP"]

month_names = {"2026-01": "January 2026", "2026-02": "February 2026", "2026-03": "March 2026"}
month_lines = [f"{month_names.get(k, k)}: {v:,.0f} EGP" for k, v in sorted(by_month.items())]
category_lines = [f"{k}: {v:,.0f} EGP" for k, v in sorted(by_category.items(), key=lambda x: x[1], reverse=True)]
city_lines = [f"{k}: {v:,.0f} EGP" for k, v in sorted(by_city.items(), key=lambda x: x[1], reverse=True)]
product_lines = [f"{k}: {v:,.0f} EGP" for k, v in sorted(by_product.items(), key=lambda x: x[1], reverse=True)[:5]]

top_category = max(by_category, key=by_category.get)
top_month = max(by_month, key=by_month.get)
top_city = max(by_city, key=by_city.get)
top_product = max(by_product, key=by_product.get)

slides = [
("Sales Analysis", "Beginner Portfolio Project\nPractice dataset • Jan–Mar 2026"),
("Dataset Overview", f"{orders} practice sales records\n7 columns: Date, City, Category, Product, Units, Unit Price, Revenue\nSynthetic learning dataset — not real company data"),
("KPI Summary", f"Total Revenue: {total_revenue:,.0f} EGP\nTotal Units: {total_units:,}\nOrders: {orders}\nAverage Order Value: {avg_order:,.2f} EGP ({avg_order:,.0f} rounded)"),
("Revenue by Month", "\n".join(month_lines)),
("Revenue by Category", "\n".join(category_lines)),
("Revenue by City", "\n".join(city_lines)),
("Top Products", "\n".join(product_lines)),
("Key Observations", f"{top_category} is the highest-revenue category.\n{month_names.get(top_month, top_month)} is the strongest month by revenue.\n{top_city} generates the highest city revenue.\n{top_product} is the top-revenue product."),
("Conclusion", "Clean/check data → calculate KPIs → aggregate → communicate findings.\nTools: Python/Pandas • SQL • Power BI-ready design"),
]

prs = Presentation()
prs.slide_width = Inches(13.333)
prs.slide_height = Inches(7.5)

for i, (title, body) in enumerate(slides):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    s.background.fill.solid()
    s.background.fill.fore_color.rgb = RGBColor(248, 250, 252)
    t = s.shapes.add_textbox(Inches(.8), Inches(.7), Inches(11.8), Inches(1)).text_frame.paragraphs[0]
    t.text = title
    t.font.size = Pt(30)
    t.font.bold = True
    t.font.color.rgb = RGBColor(15, 23, 42)
    tf = s.shapes.add_textbox(Inches(1), Inches(2), Inches(11), Inches(4.5)).text_frame
    tf.word_wrap = True
    for j, line in enumerate(body.split("\n")):
        p = tf.paragraphs[0] if j == 0 else tf.add_paragraph()
        p.text = line
        p.font.size = Pt(21)
        p.font.color.rgb = RGBColor(15, 118, 110)
        p.space_after = Pt(14)
    f = s.shapes.add_textbox(Inches(.8), Inches(6.9), Inches(11.8), Inches(.3)).text_frame.paragraphs[0]
    f.text = f"Sales Analysis • {i + 1}/{len(slides)}"
    f.font.size = Pt(10)
    f.alignment = PP_ALIGN.RIGHT
    f.font.color.rgb = RGBColor(100, 116, 139)

prs.save(OUT)
print(OUT)
