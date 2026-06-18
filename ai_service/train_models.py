import pandas as pd
import numpy as np
import os
import joblib
import xgboost as xgb
from catboost import CatBoostClassifier
from sklearn.preprocessing import MinMaxScaler
import tensorflow as tf
from tensorflow.keras import layers, models
from datetime import datetime

# Configure base directory
DATA_DIR = r'C:\Users\DELL\Desktop\gradd2'
MODELS_DIR = os.path.join(DATA_DIR, 'models')

if not os.path.exists(MODELS_DIR):
    os.makedirs(MODELS_DIR)

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

def train_demand_forecast():
    print("Training Demand Forecast Model...")
    df = load_all_sales_data()
    if df.empty: return
    monthly = df.groupby('Month')['Packs_Sold'].sum().sort_index()
    if len(monthly) < 3:
        print("Not enough data for demand forecast")
        return
    y = monthly.values.astype(float)
    X = np.arange(len(y)).reshape(-1, 1)
    model = xgb.XGBRegressor(n_estimators=100, learning_rate=0.05)
    model.fit(X, y)
    model.save_model(os.path.join(MODELS_DIR, 'demand_xgb.json'))
    print("Demand Forecast Model saved.")

def train_anomaly_detection():
    print("Training Anomaly Detection Model...")
    df = load_shift_data()
    if df.empty: return
    X_raw = df[['Expected Amount', 'Actual Amount', 'Difference']].values
    scaler = MinMaxScaler()
    X = scaler.fit_transform(X_raw)
    
    ae = models.Sequential([
        layers.Input(shape=(3,)),
        layers.Dense(8, activation='relu'),
        layers.Dense(4, activation='relu'),
        layers.Dense(3, activation='sigmoid')
    ])
    ae.compile(optimizer='adam', loss='mse')
    ae.fit(X, X, epochs=15, verbose=0)
    
    ae.save(os.path.join(MODELS_DIR, 'anomaly_ae.keras'))
    joblib.dump(scaler, os.path.join(MODELS_DIR, 'anomaly_scaler.joblib'))
    print("Anomaly Detection Model and Scaler saved.")

def train_advanced_expiry_model():
    print("Training Advanced Neural Network for Expiry Risk...")
    stock = load_stock_data()
    sales = load_all_sales_data()
    today = datetime.now()
    
    stock['Days'] = (stock['Expiry Date'] - today).dt.days.fillna(365)
    sales_v = sales.groupby('Serial No.')['Packs_Sold'].mean().reset_index().rename(columns={'Packs_Sold': 'V'})
    data = stock.merge(sales_v, on='Serial No.', how='left').fillna(0)
    
    X = data[['Packs Quantity', 'V', 'Selling Price per Pack', 'Days']].values
    target = data.apply(lambda r: 2 if r['Days'] <= 90 else (1 if r['Days'] <= 180 else 0), axis=1).values
    
    scaler = MinMaxScaler()
    X_scaled = scaler.fit_transform(X)
    
    model = models.Sequential([
        layers.Input(shape=(4,)),
        layers.Dense(32, activation='relu'),
        layers.Dense(16, activation='relu'),
        layers.Dense(3, activation='softmax')
    ])
    
    model.compile(optimizer='adam', loss='sparse_categorical_crossentropy', metrics=['accuracy'])
    model.fit(X_scaled, target, epochs=100, batch_size=32, verbose=0)
    
    model.save(os.path.join(MODELS_DIR, 'expiry_nn.keras'))
    joblib.dump(scaler, os.path.join(MODELS_DIR, 'expiry_nn_scaler.joblib'))
    print("Advanced Neural Network Expiry Model saved.")

def train_q_learning_reorder():
    print("Training Q-Learning for Reorder Engine...")
    states = 21
    actions = 5
    q_table = np.zeros((states, actions))
    alpha, gamma, epsilon, episodes = 0.1, 0.9, 0.1, 5000
    
    for _ in range(episodes):
        state = np.random.randint(0, states)
        for _ in range(30):
            action = np.random.randint(0, actions) if np.random.uniform(0, 1) < epsilon else np.argmax(q_table[state])
            order_qty = action * 5
            demand = np.random.poisson(10)
            new_stock = min(states - 1, state + order_qty)
            sold = min(new_stock, demand)
            next_state = new_stock - sold
            reward = sold * 10 - (next_state * 2) - (max(0, demand - new_stock) * 20)
            q_table[state, action] = q_table[state, action] + alpha * (reward + gamma * np.max(q_table[next_state]) - q_table[state, action])
            state = next_state

    joblib.dump(q_table, os.path.join(MODELS_DIR, 'q_table_reorder.joblib'))
    print("Q-Learning Reorder Table saved.")

if __name__ == '__main__':
    train_demand_forecast()
    train_anomaly_detection()
    train_advanced_expiry_model()
    train_q_learning_reorder()
    print("All models trained and saved successfully.")
