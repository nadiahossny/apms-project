import pandas as pd
import numpy as np
import os
import joblib
import xgboost as xgb
from catboost import CatBoostClassifier
from sklearn.metrics import accuracy_score, r2_score, mean_squared_error
from sklearn.preprocessing import MinMaxScaler
import tensorflow as tf
from tensorflow.keras import models
from datetime import datetime

DATA_DIR = r'C:\Users\DELL\Desktop\gradd2'
MODELS_DIR = os.path.join(DATA_DIR, 'models')

def load_all_sales_data():
    all_data = []
    for i in range(1, 13):
        file_path = os.path.join(DATA_DIR, f'{i}.xlsx')
        if os.path.exists(file_path):
            df = pd.read_excel(file_path)
            df['Month'] = i
            all_data.append(df)
    if not all_data: return pd.DataFrame()
    combined = pd.concat(all_data, ignore_index=True)
    if 'Packs Sold ' in combined.columns: combined['Packs_Sold'] = pd.to_numeric(combined['Packs Sold '], errors='coerce').fillna(0)
    elif 'Packs Sold' in combined.columns: combined['Packs_Sold'] = pd.to_numeric(combined['Packs Sold'], errors='coerce').fillna(0)
    else: combined['Packs_Sold'] = 0
    return combined

def load_stock_data():
    df = pd.read_excel(os.path.join(DATA_DIR, 'Stock.xlsx'))
    df['Expiry Date'] = pd.to_datetime(df['Expiry Date'], errors='coerce')
    df = df[df['Total Inventory Value'] >= 0]
    return df

def load_shift_data():
    df = pd.read_excel(os.path.join(DATA_DIR, 'Sales per shif.xlsx'))
    df['Start Date'] = pd.to_datetime(df['Start Date'], errors='coerce')
    for col in ['Expected Amount', 'Actual Amount', 'Difference']:
        df[col] = pd.to_numeric(df[col], errors='coerce').fillna(0)
    return df

def evaluate_models():
    results = {}

    # 1. XGBoost Demand Forecast
    print("Evaluating XGBoost Demand Forecast...")
    df = load_all_sales_data()
    if not df.empty:
        monthly = df.groupby('Month')['Packs_Sold'].sum().sort_index()
        y = monthly.values.astype(float)
        X = np.arange(len(y)).reshape(-1, 1)
        
        model = xgb.XGBRegressor()
        model.load_model(os.path.join(MODELS_DIR, 'demand_xgb.json'))
        y_pred = model.predict(X)
        r2 = r2_score(y, y_pred)
        results['XGBoost Demand Forecast (R² Score)'] = f"{r2*100:.2f}%"

    # 2. Advanced NN Expiry Risk (Primary)
    print("Evaluating Advanced Neural Network Expiry Risk...")
    stock = load_stock_data()
    sales = load_all_sales_data()
    today = datetime.now()
    stock['Days'] = (stock['Expiry Date'] - today).dt.days.fillna(365)
    sales_v = sales.groupby('Serial No.')['Packs_Sold'].mean().reset_index().rename(columns={'Packs_Sold': 'V'})
    data = stock.merge(sales_v, on='Serial No.', how='left').fillna(0)
    y_true = data.apply(lambda r: 2 if r['Days'] <= 90 else (1 if r['Days'] <= 180 else 0), axis=1)

    X_nn_raw = data[['Packs Quantity', 'V', 'Selling Price per Pack', 'Days']].values
    scaler_nn = joblib.load(os.path.join(MODELS_DIR, 'expiry_nn_scaler.joblib'))
    X_nn_scaled = scaler_nn.transform(X_nn_raw)
    model_nn = models.load_model(os.path.join(MODELS_DIR, 'expiry_nn.keras'))
    y_pred_nn_probs = model_nn.predict(X_nn_scaled)
    y_pred_nn = np.argmax(y_pred_nn_probs, axis=1)
    acc_nn = accuracy_score(y_true, y_pred_nn)
    results['Advanced NN Expiry Risk (Accuracy)'] = f"{acc_nn*100:.2f}%"

    # 3. Autoencoder Anomaly Detection
    print("Evaluating Autoencoder Anomaly Detection...")
    df_shift = load_shift_data()
    if not df_shift.empty:
        scaler = joblib.load(os.path.join(MODELS_DIR, 'anomaly_scaler.joblib'))
        X_ae = scaler.transform(df_shift[['Expected Amount', 'Actual Amount', 'Difference']].values)
        model_ae = models.load_model(os.path.join(MODELS_DIR, 'anomaly_ae.keras'))
        reconstruction = model_ae.predict(X_ae)
        mse = mean_squared_error(X_ae, reconstruction)
        results['Autoencoder Anomaly Detection (MSE)'] = f"{mse:.6f}"

    # 4. Q-Learning Reorder Engine
    print("Evaluating Q-Learning Reorder Engine...")
    q_table = joblib.load(os.path.join(MODELS_DIR, 'q_table_reorder.joblib'))
    avg_q_value = np.mean(np.max(q_table, axis=1))
    results['Q-Learning Reorder Engine (Mean Expected Reward)'] = f"{avg_q_value:.2f}"

    return results

if __name__ == '__main__':
    eval_results = evaluate_models()
    print("\n--- Model Evaluation Summary ---")
    for model, score in eval_results.items():
        print(f"{model}: {score}")
