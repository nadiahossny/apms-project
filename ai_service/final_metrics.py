import pandas as pd
import numpy as np
import os
import joblib
import tensorflow as tf
from tensorflow.keras import models
from sklearn.metrics import accuracy_score
from sklearn.preprocessing import MinMaxScaler
from sklearn.ensemble import RandomForestClassifier
from lightgbm import LGBMClassifier
from datetime import datetime
from pytorch_tabnet.tab_model import TabNetClassifier
import warnings

warnings.filterwarnings('ignore')

DATA_DIR = r'C:\Users\DELL\Desktop\gradd2'
MODELS_DIR = os.path.join(DATA_DIR, 'models')

def load_data():
    # Load Stock
    stock = pd.read_excel(os.path.join(DATA_DIR, 'Stock.xlsx'))
    stock['Expiry Date'] = pd.to_datetime(stock['Expiry Date'], errors='coerce')
    
    # Load Sales for velocity
    all_sales = []
    for i in range(1, 13):
        p = os.path.join(DATA_DIR, f'{i}.xlsx')
        if os.path.exists(p):
            df = pd.read_excel(p)
            if 'Packs Sold ' in df.columns: df['V'] = pd.to_numeric(df['Packs Sold '], errors='coerce')
            elif 'Packs Sold' in df.columns: df['V'] = pd.to_numeric(df['Packs Sold'], errors='coerce')
            all_sales.append(df[['Serial No.', 'V']])
    
    sales_df = pd.concat(all_sales).groupby('Serial No.')['V'].mean().reset_index().fillna(0)
    
    today = datetime.now()
    stock['Days'] = (stock['Expiry Date'] - today).dt.days.fillna(365)
    data = stock.merge(sales_df, on='Serial No.', how='left').fillna(0)
    
    X = data[['Packs Quantity', 'V', 'Selling Price per Pack', 'Days']].values
    y = data.apply(lambda r: 2 if r['Days'] <= 90 else (1 if r['Days'] <= 180 else 0), axis=1).values
    return X, y

def evaluate_all():
    X, y = load_data()
    scaler = joblib.load(os.path.join(MODELS_DIR, 'expiry_nn_scaler.joblib'))
    X_scaled = scaler.transform(X)
    
    results = {}

    # 1. NN
    model_nn = models.load_model(os.path.join(MODELS_DIR, 'expiry_nn.keras'))
    results['Deep Neural Network'] = accuracy_score(y, np.argmax(model_nn.predict(X_scaled, verbose=0), axis=1))

    # 2. TabNet
    model_tn = TabNetClassifier()
    model_tn.load_model(os.path.join(MODELS_DIR, 'expiry_tabnet.zip'))
    results['TabNet'] = accuracy_score(y, model_tn.predict(X))

    # 3. SVM
    model_svm = joblib.load(os.path.join(MODELS_DIR, 'expiry_svm.joblib'))
    results['SVM'] = accuracy_score(y, model_svm.predict(X_scaled))

    # 4. Random Forest (Train/Eval on fly for metrics)
    rf = RandomForestClassifier(n_estimators=100, random_state=42)
    rf.fit(X, y)
    results['Random Forest'] = accuracy_score(y, rf.predict(X))

    # 5. LightGBM (Train/Eval on fly for metrics)
    lgbm = LGBMClassifier(n_estimators=100, random_state=42, verbose=-1)
    lgbm.fit(X, y)
    results['LightGBM'] = accuracy_score(y, lgbm.predict(X))

    for m, acc in results.items():
        print(f"{m}:{acc*100:.2f}%")

if __name__ == '__main__':
    evaluate_all()
