# Pharmacy Intelligence Dashboard

AI-powered inventory and sales analytics dashboard for pharmacy management.

## Features

### 1. Sales Analysis (Files 1-12)
- **Pareto Analysis (80/20)**: Identify top 20% products generating 80% of profits
- **Dead Stock Analysis**: Find items with zero sales for clearance
- **Manufacturer Performance**: Track supplier performance (e.g., Pharmaoverseas vs IBN SINA)
- **Inventory Turnover**: Monitor how long items stay on shelf

### 2. Visualizations
- **Seasonality Curves**: Monthly sales patterns by category
- **Monthly Comparison**: Growth rate tracking
- **Category Distribution**: Pie chart of sales by category
- **Revenue vs Profit**: Line chart comparison

### 3. AI & Predictions
- **ARIMA Forecasting**: Time series demand prediction
- **SARIMA Forecasting**: Seasonal demand forecasting
- **Smart Reorder Point**: Automatic reorder calculation
- **Anomaly Detection**: Identify unusual sales patterns

### 4. Shift Analysis
- **Peak Hours**: Identify best performing shifts
- **Cashier Accuracy**: Track variance by cashier
- **Cash Flow**: Daily cash flow tracking
- **Variance Distribution**: Monitor cash management quality

### 5. Expiry Management
- **Traffic Light System**: Red/Yellow/Green expiry alerts
- **Expiry Timeline**: Monthly value at risk chart
- **Category Health**: Risk percentage by category
- **Discount Optimizer**: AI-suggested discounts for expiring stock

## Installation

```bash
pip install flask pandas numpy openpyxl statsmodels
```

## Running the Dashboard

```bash
python app.py
```

Then open your browser to: `http://localhost:5000`

## Data Requirements

The dashboard expects the following Excel files in the same directory:
- `1.xlsx` through `12.xlsx`: Monthly sales data
- `Stock.xlsx`: Inventory with expiry dates
- `Sales per shif.xlsx`: Shift transaction data

### Column Requirements

**Sales Files (1-12):**
- Serial No., Product Name, Packs Sold, Strips Sold, Selling Price per Pack, Total Selling Value, Supplier, Category, Stock on Hand

**Stock.xlsx:**
- Serial No., Product Name, Selling Price per Pack, Expiry Date, Packs Quantity, Strips Quantity, Total Inventory Value, Category

**Sales per shif.xlsx:**
- ID, Start Date, Start Time, End Date, End Time, Expected Amount, Actual Amount, Difference

## Notes

- Product Name = 0 means item needs reorder
- Supplier = "صباح الفل" is renamed to "Unknown"
- Stock on Hand format "1:02" = 1 pack + 2 strips
