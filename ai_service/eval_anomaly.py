import pandas as pd
import numpy as np
import os
import joblib
import tensorflow as tf
from tensorflow.keras import layers, models
from sklearn.preprocessing import MinMaxScaler
from sklearn.ensemble import IsolationForest
from sklearn.svm import OneClassSVM
from sklearn.metrics import mean_squared_error
import warnings

warnings.filterwarnings('ignore')

DATA_DIR = r'C:\Users\DELL\Desktop\gradd2'
MODELS_DIR = os.path.join(DATA_DIR, 'models')

def load_shift_data():
    df = pd.read_excel(os.path.join(DATA_DIR, 'Sales per shif.xlsx'))
    for col in ['Expected Amount', 'Actual Amount', 'Difference']:
        df[col] = pd.to_numeric(df[col], errors='coerce').fillna(0)
    return df[['Expected Amount', 'Actual Amount', 'Difference']].values

def evaluate_anomalies():
    X_raw = load_shift_data()
    scaler = MinMaxScaler()
    X = scaler.fit_transform(X_raw)
    
    results = {}

    # 1. Standard Autoencoder (Current)
    ae_path = os.path.join(MODELS_DIR, 'anomaly_ae.keras')
    if os.path.exists(ae_path):
        ae = models.load_model(ae_path)
        reconstruction = ae.predict(X, verbose=0)
        mse = mean_squared_error(X, reconstruction)
        results['Autoencoder (AE)'] = mse
    
    # 2. Variational Autoencoder (VAE) - Training a quick one for comparison
    input_dim = 3
    latent_dim = 2
    
    inputs = layers.Input(shape=(input_dim,))
    h = layers.Dense(8, activation='relu')(inputs)
    z_mean = layers.Dense(latent_dim)(h)
    z_log_var = layers.Dense(latent_dim)(h)
    
    def sampling(args):
        z_mean, z_log_var = args
        epsilon = tf.random.normal(shape=(tf.shape(z_mean)[0], latent_dim))
        return z_mean + tf.exp(0.5 * z_log_var) * epsilon

    z = layers.Lambda(sampling)([z_mean, z_log_var])
    decoder_h = layers.Dense(8, activation='relu')
    decoder_mean = layers.Dense(input_dim, activation='sigmoid')
    h_decoded = decoder_h(z)
    x_decoded_mean = decoder_mean(h_decoded)
    
    vae = models.Model(inputs, x_decoded_mean)
    vae.compile(optimizer='adam', loss='mse')
    vae.fit(X, X, epochs=10, verbose=0)
    vae_reconstruction = vae.predict(X, verbose=0)
    results['VAE'] = mean_squared_error(X, vae_reconstruction)

    # 3. Isolation Forest
    iso = IsolationForest(contamination=0.05, random_state=42)
    iso.fit(X)
    scores = iso.decision_function(X)
    results['Isolation Forest'] = np.mean(np.abs(scores)) # Average anomaly score depth

    # 4. One-Class SVM
    oc_svm = OneClassSVM(nu=0.05, kernel="rbf", gamma=0.1)
    oc_svm.fit(X)
    results['One-Class SVM'] = np.mean(np.abs(oc_svm.decision_function(X)))

    for m, score in results.items():
        print(f"{m}:{score:.6f}")

if __name__ == '__main__':
    evaluate_anomalies()
