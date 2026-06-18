# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  preload.py — Run this script to load the Search Engine
#  and check Ollama, then start the API server instantly!
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import time
import uvicorn
import requests

print("━" * 60)
print("🚀 STARTING PRELOADING SEQUENCE")
print("━" * 60)

start_time = time.time()

# ━━━━━━ 1. Load Search Engine (CSV, FAISS, Model, ES) ━━━━━━
print("\n⏳ [1/2] Loading Search Engine & Database...")
from ocr_core import init_search
init_search()

# ━━━━━━ 2. Check Ollama Connection for GLM-OCR ━━━━━━
print("\n⏳ [2/2] Checking Ollama Connection (GLM-OCR)...")
try:
    r = requests.get("http://localhost:11434/api/tags", timeout=3)
    if r.status_code == 200:
        print("   ✅ Ollama is running and reachable.")
    else:
        print("   ⚠️ Ollama returned a non-200 status. Make sure it is running!")
except Exception:
    print("   ⚠️ Ollama is NOT reachable! GLM-OCR will fail. Start Ollama first.")

elapsed = time.time() - start_time
print("\n" + "━" * 60)
print(f"✅ PRELOADING COMPLETE in {elapsed:.2f} seconds")
print("🚀 Starting FastAPI Server now (instant startup)...")
print("━" * 60 + "\n")

# ━━━━━━ Start the API ━━━━━━
from app import app
uvicorn.run(app, host="0.0.0.0", port=5001)