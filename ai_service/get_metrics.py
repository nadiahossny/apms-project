import pandas as pd
import numpy as np
import os
import joblib
import tensorflow as tf
from tensorflow.keras import models
from sklearn.metrics import accuracy_score
from sklearn.preprocessing import MinMaxScaler
from datetime import datetime
from pytorch_tabnet.tab_model import TabNetClassifier
import torch

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

def evaluate():
    stock = load_stock_data()
    sales = load_all_sales_data()
    today = datetime.now()
    
    stock['Days'] = (stock['Expiry Date'] - today).dt.days.fillna(365)
    sales_v = sales.groupby('Serial No.')['Packs_Sold'].mean().reset_index().rename(columns={'Packs_Sold': 'V'})
    data = stock.merge(sales_v, on='Serial No.', how='left').fillna(0)
    
    X = data[['Packs Quantity', 'V', 'Selling Price per Pack', 'Days']].values
    y_true = data.apply(lambda r: 2 if r['Days'] <= 90 else (1 if r['Days'] <= 180 else 0), axis=1).values

    results = {}

    # 1. Neural Network
    print("Evaluating NN...")
    scaler_nn = joblib.load(os.path.join(MODELS_DIR, 'expiry_nn_scaler.joblib'))
    X_nn = scaler_nn.transform(X)
    model_nn = models.load_model(os.path.join(MODELS_DIR, 'expiry_nn.keras'))
    y_pred_nn = np.argmax(model_nn.predict(X_nn, verbose=0), axis=1)
    results['Deep Neural Network'] = accuracy_score(y_true, y_pred_nn)

    # 2. SVM
    print("Evaluating SVM...")
    # Assume SVM uses the same scaler or has its own? 
    # Usually SVM needs scaling. Let's see if there is another scaler.
    # If not, I'll try with the NN scaler or fit a new one if it's a raw model.
    # Actually, most saved SVM models include the pipeline or were trained on some scale.
    model_svm = joblib.load(os.path.join(MODELS_DIR, 'expiry_svm.joblib'))
    # Try to predict. If it fails due to scaling, I might need to guess.
    # But usually, if it's just the model, it expects scaled input.
    try:
        y_pred_svm = model_svm.predict(X_nn)
        results['SVM'] = accuracy_score(y_true, y_pred_svm)
    except Exception as e:
        print(f"SVM Error: {e}")
        # Try raw X if scaled fails
        try:
            y_pred_svm = model_svm.predict(X)
            results['SVM'] = accuracy_score(y_true, y_pred_svm)
        except:
            results['SVM'] = "N/A"

    # 3. TabNet
    print("Evaluating TabNet...")
    try:
        model_tabnet = TabNetClassifier()
        model_tabnet.load_model(os.path.join(MODELS_DIR, 'expiry_tabnet.zip'))
        # TabNet often works well with raw features or its own scaling
        y_pred_tabnet = model_tabnet.predict(X)
        results['TabNet'] = accuracy_score(y_true, y_pred_tabnet)
    except Exception as e:
        print(f"TabNet Error: {e}")
        results['TabNet'] = "N/A"

    return results

if __name__ == '__main__':
    res = evaluate()
    for m, acc in res.items():
        if isinstance(acc, float):
            print(f"{m}: {acc*100:.2f}%")
        else:
            print(f"{m}: {acc}")
