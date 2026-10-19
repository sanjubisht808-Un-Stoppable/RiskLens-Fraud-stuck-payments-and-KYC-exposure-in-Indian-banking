# RiskLens: Indian Banking Transactions Analysis

**Fraud, stuck payments and KYC exposure** | Python | MySQL | Power BI | 550,000 transactions

## Overview
End-to-end analytics on 550,000 banking transactions. It answers where fraud is concentrated, how much money is stuck in failed, pending or reversed payments, and how much value moved while KYC was pending or expired. Data was audited and cleaned in Python, every KPI was rebuilt in MySQL and reconciled against Python, and the results are shown in a three-page Power BI dashboard.

**Headline finding:** transactions above ₹5 lakh are 1.1% of volume but hold about 84% of fraud value.

## Business problems
| # | Problem | Question |
|---|---|---|
| 1 | Fraud | If reviewers can check only a few transactions, which first: by count or by rupees? |
| 2 | Stuck money | How much value is Failed, Pending or Reversed, and where should recovery start? |
| 3 | KYC exposure | How much value moved with KYC not verified, and where is risk biggest? |

## Tools
- **Python** (pandas, numpy, seaborn, matplotlib): audit, cleaning, features, EDA
- **MySQL 8**: tables, KPI queries, window functions, views, indexes
- **Power BI**: DAX measures, slicers, 3-page dashboard

## Workflow
1. Audit the data (nulls, duplicates, impossible amounts, is `customer_id` reliable?)
2. Clean and engineer features (amount bands, fraud value, status and KYC flags)
3. Explore each problem in Python
4. Load into MySQL and rebuild every KPI in SQL
5. Reconcile SQL against Python (match to two decimals)
6. Create views, load into Power BI, build the dashboard

## Key findings
| Area | Finding |
|---|---|
| Fraud | 0.89% of transactions are fraud, so accuracy is a misleading measure |
| Fraud | Above ₹5L: 1.1% of volume, about 84% of fraud value (8.22% fraud rate vs 0.80% below) |
| Fraud | UPI has the most cases (1,211) but only ₹0.16 cr; RTGS has 611 cases and ₹38.56 cr |
| Review capacity | Top 1% by amount protects about 81% of fraud value but catches only about 9% of cases |
| Stuck money | ₹135.7 cr: Failed ₹69.69 cr, Pending ₹33.45 cr, Reversed ₹32.58 cr |
| Stuck money | Failure rate is about 8% for every type, yet RTGS holds ₹71.67 cr of the stuck value |
| KYC | ₹203 cr (12.4% of value) moved with KYC Pending or Expired |
| KYC | 218 transactions of ₹10L or more (₹38.5 cr) had KYC not verified; RTGS accounts for ₹109.33 cr |

## Recommendations
1. **Tier fraud review by value:** review transactions above ₹5L first; use light automated checks for UPI.
2. **Recover stuck money by rupee size:** RTGS, Cheque and NEFT hold 88% of it; set an ageing limit for Pending.
3. **Step-up KYC on large payments:** re-verify at ₹10L or more; start with RTGS, Maharashtra, Karnataka, Tamil Nadu.

## Dashboard
![Fraud page](images/page1_fraud.png.png)
![Stuck money page](images/page2_stuck_money.png.png)
![KYC page](images/page3_kyc.png.png)

## Techniques
- **Python:** groupby/agg, `pd.cut`, 1/0 flags, cumulative sums, seaborn and matplotlib
- **SQL:** GROUP BY, CASE WHEN, CTEs, ROW_NUMBER, running SUM OVER, RANK with PARTITION BY, views, indexes
- **Power BI:** DAX (CALCULATE, DIVIDE), measures vs columns, slicers

## Limitations
- `customer_id` is not reliable (only 0.7% of customers have one credit score), so no segmentation or churn model
- The fraud step at exactly ₹5,00,000 looks rule-generated; validate on real data before using it as policy
- No variable explained failure (about 8% everywhere), so no prediction model
- KYC status is per transaction, so findings describe transactions, not customers
- The dataset appears simulated. Source: [add dataset link]

## Repository structure
```
/notebook    Indian_Bank_Analysis.ipynb
/sql         queries.sql
/powerbi     RiskLens_Indian_Banking.pbix
/images      page1_fraud.png  page2_stuck_money.png  page3_kyc.png
/docs        RiskLens_Complete_Learning_Guide.pdf
README.md
```

## How to reproduce
1. Run the notebook cells in order (writes `transactions_clean.csv`)
2. In MySQL Workbench create `bank_project`, create the `transactions` table, load the cleaned file
3. Run `queries.sql` for indexes, views and the `capacity_curve` table
4. Open the `.pbix`, point it at your MySQL server, refresh

The raw 550,000-row file is not included (GitHub rejects files over 100 MB).

## Author
[Sanjay Singh]
