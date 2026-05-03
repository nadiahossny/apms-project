import io
import time
import json
import hashlib
import csv
from pathlib import Path
from difflib import SequenceMatcher
from PIL import Image
import ollama
import requests
import re

# ================= CONFIGURATION =================
BASE_DIR = Path("./results")
CACHE_DIR = BASE_DIR / ".cache"
CACHE_DIR.mkdir(parents=True, exist_ok=True)

MODEL_NAME = "glm-ocr:latest"
MEDICINES_CSV_PATH = "medicines_data_updated.csv"

# ================= DATABASE STRUCTURES =================
MEDICINES_MAP = {}      
MEDICINES_LIST = []     
MEDICINES_DB = set()    

def keep_english_only(text: str) -> str:
    cleaned = re.sub(r'[^a-zA-Z0-9\s]', '', text)
    return re.sub(r'\s+', ' ', cleaned).strip()

def load_medicines_db():
    global MEDICINES_MAP, MEDICINES_LIST, MEDICINES_DB
    csv_path = Path(MEDICINES_CSV_PATH)
    if not csv_path.exists():
        print(f"WARNING: CSV not found at {MEDICINES_CSV_PATH}")
        return
    try:
        with open(csv_path, 'r', encoding='utf-8-sig') as f:
            reader = csv.DictReader(f)
            for row in reader:
                name = None
                for col in ['Drugname', 'drug_name', 'medicine_name', 'name', 
                           'generic_name', 'brand_name', 'Medicine', 'medicine', 'Drug', 'drug']:
                    if col in row and row[col]:
                        name = row[col].strip()
                        break
                if name:
                    eng_clean = keep_english_only(name).lower().strip()
                    
                    if not eng_clean or len(eng_clean) < 3:
                        continue
                    if not re.search(r'[a-zA-Z]', eng_clean):
                        continue
                        
                    if eng_clean not in MEDICINES_MAP:
                        MEDICINES_MAP[eng_clean] = eng_clean.title()
                        
                    MEDICINES_DB.add(eng_clean)
                    MEDICINES_LIST.append(eng_clean.title())
        print(f"Loaded {len(MEDICINES_MAP)} clean English medicines.")
    except Exception as e:
        print(f"WARNING: CSV Error: {e}")

load_medicines_db()

# ================= MASTER OCR VISUAL MAP =================
OCR_VISUAL_MAP = {
    'a': ['o', 'u', 'e', 'd', 'q'], 'b': ['p', 'd', 'h', 'l', '6'],
    'c': ['e', 'o', 'a', 'u', 'l'], 'd': ['a', 'p', 'b', 'o', 'cl'],
    'e': ['c', 'o', 'a', 'l'], 'f': ['t', 'p', '7'],
    'g': ['q', 'y', 'j', '9', '8'], 'h': ['n', 'b', 'k', 'u', 'li', '4'],
    'i': ['l', 'j', '1', 't', '!'], 'j': ['i', 'y', 'l'],
    'k': ['h', 'x', 'r', '4'], 'l': ['1', 'i', 'e', 't'],
    'm': ['n', 'rn', 'w', 'in', 'ni'], 'n': ['u', 'r', 'm', 'h', 'v'],
    'o': ['0', 'a', 'c', 'e', 'u', 'q', 'd'], 'p': ['q', 'b', 'd', 'g'],
    'q': ['p', 'g', 'o', '9'], 'r': ['n', 'v', 't', 'x', 'i'],
    's': ['5', 'z', '8'], 't': ['f', 'l', 'r', '+', '7'],
    'u': ['v', 'n', 'a', 'r'], 'v': ['u', 'y', 'r'],
    'w': ['vv', 'm', 'u'], 'x': ['z', 'k', '+'],
    'y': ['v', 'g', 'j'], 'z': ['2', 's', 'x', '7'],
    'A': ['H', 'R', '4'], 'B': ['E', '8', 'P', 'R'],
    'C': ['G', 'O', 'U', 'L'], 'D': ['O', '0', 'P', 'Q'],
    'E': ['F', 'B', '3'], 'F': ['E', 'P', '7'],
    'G': ['C', 'O', '6', 'B'], 'H': ['A', 'N', '4', 'M'],
    'I': ['L', '1', 'T', '7'], 'J': ['L', 'T', 'U'],
    'K': ['X', 'H', 'R'], 'L': ['1', 'I', 'S'],
    'M': ['N', 'W', 'H', 'RN'], 'N': ['M', 'H', 'V', 'Z'],
    'O': ['0', 'D', 'Q', 'C'], 'P': ['R', 'F', 'B', 'D'],
    'Q': ['O', 'D', 'G', 'C'], 'R': ['P', 'K', 'B'],
    'S': ['5', '8'], 'T': ['I', '7', 'L', 'F'],
    'U': ['V', 'W'], 'V': ['U', 'Y', 'W'],
    'W': ['M', 'V', 'U'], 'X': ['K', 'Z'],
    'Y': ['V', 'X', 'T'], 'Z': ['2', '7', 'N'],
    '0': ['O', 'o', 'D', 'Q', 'C'], '1': ['I', 'i', 'l', 'L', 'T'],
    '2': ['Z', 'z', '7'], '3': ['E', 'e', 'B', '8'],
    '4': ['A', 'H', 'h', 'K'], '5': ['S', 's'],
    '6': ['G', 'b', '9'], '7': ['T', 'F', 'Z', 'z', '2'],
    '8': ['B', 'S', 'g'], '9': ['g', 'q', 'P', '6']
}

MULTI_CHAR_MAP = {
    "rn": "m", "m": "rn", "ni": "m", "li": "h", "ij": "u",
    "w": "vv", "vv": "w", "cl": "d", "d": "cl"
}

def generate_ocr_variants(text: str) -> list:
    variants = set([text]) 
    for wrong_comb, right_char in MULTI_CHAR_MAP.items():
        if wrong_comb in text:
            variants.add(text.replace(wrong_comb, right_char))
            
    chars = list(text)
    for i in range(len(chars)):
        c = chars[i]
        alts = OCR_VISUAL_MAP.get(c)
        if alts:
            if isinstance(alts, str): alts = [alts]
            for alt in alts:
                new_chars = chars.copy()
                new_chars[i] = alt
                variants.add("".join(new_chars))
                
    return list(variants)


# ================= THE TWO-PASS ULTIMATE ENGINE =================

def smart_medicine_search(query: str) -> dict:
    query_clean = keep_english_only(query).lower().strip()
    
    if not query_clean or len(query_clean) < 3:
        return {"original": query, "corrected": query, "valid": False, "score": 0, "method": "too_short"}
    
    if query_clean in MEDICINES_MAP:
        return {"original": query, "corrected": MEDICINES_MAP[query_clean], "valid": True, "score": 1.0, "method": "exact"}
    
    best_score = 0.0
    best_match_key = None
    best_method = "none"
    THRESHOLD = 0.70
    candidates_pass1 = []
    
    # ==========================================
    # PASS 1: BLAZING FAST STANDARD FUZZY (0.2s)
    # ==========================================
    for db_key in MEDICINES_MAP:
        if abs(len(query_clean) - len(db_key)) > 5:
            continue
            
        score = 0.0
        method = "none"
        
        if len(query_clean) >= 4 and db_key.startswith(query_clean):
            missing_chars = len(db_key) - len(query_clean)
            score = max(0.70, 1.0 - (missing_chars * 0.03))
            method = "prefix"
        else:
            score = SequenceMatcher(None, query_clean, db_key).ratio()
            if score >= THRESHOLD:
                method = "fuzzy"
            else:
                score = 0.0
                
        if score > best_score:
            best_score = score
            best_match_key = db_key
            best_method = method
            
        if score >= 0.60:
            candidates_pass1.append((db_key, score))
            
    # If Pass 1 found >= 0.80, it's mathematically safe. Return immediately!
    if best_score >= 0.80:
        return {
            "original": query, "corrected": MEDICINES_MAP[best_match_key],
            "valid": True, "score": round(best_score, 3), "method": best_method
        }
    
    # ==========================================
    # PASS 2: OCR VISUAL FIX (Only top 100 closest)
    # ==========================================
    candidates_pass1.sort(key=lambda x: x[1], reverse=True)
    top_candidates = [item[0] for item in candidates_pass1[:100]]
    queries_to_try = generate_ocr_variants(query_clean)
    
    for db_key in top_candidates:
        for q in queries_to_try:
            score = 0.0
            method = "none"
            
            if len(q) >= 4 and db_key.startswith(q):
                missing_chars = len(db_key) - len(q)
                score = max(0.70, 1.0 - (missing_chars * 0.03))
                method = "prefix"
            else:
                score = SequenceMatcher(None, q, db_key).ratio()
                if score >= THRESHOLD:
                    method = "ocr_visual_fix"
                else:
                    score = 0.0
                    
            if score > best_score:
                is_valid = False
                
                if score >= 0.80:
                    # HIGH CONFIDENCE ZONE
                    is_valid = True
                elif score >= 0.70:
                    # DANGER ZONE: Max 2 actual character changes allowed!
                    # This blocks Tussiibm (3 diffs) and Elballerge (9 diffs)
                    zip_diffs = sum(c1 != c2 for c1, c2 in zip(q, db_key))
                    len_diff = abs(len(q) - len(db_key))
                    if (zip_diffs + len_diff) <= 2:
                        is_valid = True
                
                if is_valid:
                    best_score = score
                    best_match_key = db_key
                    best_method = method
            
    if best_match_key and best_score >= THRESHOLD:
        return {
            "original": query, "corrected": MEDICINES_MAP[best_match_key],
            "valid": True, "score": round(best_score, 3), "method": best_method
        }
        
    return {"original": query, "corrected": query, "valid": False, "score": round(best_score, 3), "method": "none"}

# ================= AGGRESSIVE PARSER =================

ERASE_WORDS = [
    "textcircled", "vial", "ly", "bd", "add", "rc", "date", "rx", "sig",
    "tablet", "capsule", "tab", "cap", "mg", "ml", "g", "mcg", "iv", "im", "sc",
    "take", "daily", "after", "before", "with", "food", "water", "dr", "doctor",
    "patient", "name", "age", "sex", "weight", "medicine", "drug", "prescription",
    "once", "twice", "times", "day", "night", "morning", "evening", "oral", "topical",
    "injection", "syrup", "for", "days", "week", "weeks", "month", "as", "needed",
    "one", "two", "three", "four", "five", "six", "od", "tds", "qid", "prn"
]

def aggressive_clean(line: str) -> str:
    pattern = r'\b(?:' + '|'.join(re.escape(w) for w in ERASE_WORDS) + r')\b'
    line = re.sub(pattern, ' ', line, flags=re.IGNORECASE)
    line = re.sub(r'\b\d+\b', '', line)
    line = re.sub(r'[^a-zA-Z\s]', '', line)
    return re.sub(r'\s+', ' ', line).strip()

def smart_parse(text: str) -> list:
    if not text: return []
    lines = text.split("\n")
    candidates = set()
    
    for line in lines:
        clean_line = aggressive_clean(line)
        words = clean_line.split()
        
        current_group = []
        for word in words:
            if len(word) >= 4 and word[0].isupper():
                current_group.append(word)
            else:
                if current_group:
                    candidates.add(" ".join(current_group))
                    for w in current_group:
                        candidates.add(w)
                    current_group = []
        
        if current_group:
            candidates.add(" ".join(current_group))
            for w in current_group:
                candidates.add(w)
                
    return list(candidates)

# ================= VALIDATION =================

def validate_and_correct_medicines(meds: list) -> list:
    results = [smart_medicine_search(med) for med in meds]
    seen_corrected = {}
    for r in results:
        corrected = r["corrected"]
        if corrected not in seen_corrected or r["score"] > seen_corrected[corrected]["score"]:
            seen_corrected[corrected] = r
    return list(seen_corrected.values())

# ================= CACHING & PREPROCESSING =================
def cache_key(data: bytes): return hashlib.md5(data).hexdigest()[:16]
def load_cache(data: bytes):
    file = CACHE_DIR / f"{cache_key(data)}.json"
    return json.loads(file.read_text()) if file.exists() else None
def save_cache(data: bytes, result: dict):
    file = CACHE_DIR / f"{cache_key(data)}.json"
    file.write_text(json.dumps(result, ensure_ascii=False))

def load_image_from_url(url: str) -> bytes:
    try:
        r = requests.get(url, timeout=30, stream=True)
        r.raise_for_status()
        return r.content
    except Exception as e:
        raise Exception(f"Failed to download image: {str(e)}")

def preprocess(image_bytes: bytes) -> bytes:
    with Image.open(io.BytesIO(image_bytes)) as img:
        img = img.convert("L")
        img.thumbnail((800, 800))
        buffer = io.BytesIO()
        img.save(buffer, format="PNG")
        return buffer.getvalue()

# ================= MODEL =================
def run_model(image_bytes: bytes) -> tuple:
    start = time.time()
    try:
        response = ollama.chat(
            model=MODEL_NAME,
            messages=[
                {"role": "system", "content": "Extract prescription text only."},
                {"role": "user", "content": "Extract text", "images": [image_bytes]}
            ],
            options={"temperature": 0.0, "num_ctx": 512, "num_predict": 150, "num_thread": 8, "top_k": 50, "top_p": 0.9, "repeat_penalty": 1.1}
        )
        return response["message"]["content"].strip(), time.time() - start
    except Exception as e:
        print(f"Model failed: {e}")
        return "", time.time() - start

# ================= PIPELINE =================
def extract(image_bytes: bytes) -> dict:
    start_total = time.time()
    cached = load_cache(image_bytes)
    if cached:
        cached["cache"] = True
        cached["total_time"] = round(time.time() - start_total, 2)
        return cached
    
    try:
        img = preprocess(image_bytes)
    except Exception as e:
        return {"medicine_names": [], "validated_medicines": [], "raw_extracted": [], "count": 0, "raw_count": 0, "api_time": 0, "total_time": round(time.time() - start_total, 2), "cache": False, "error": str(e), "model": MODEL_NAME}
    
    text, api_time = run_model(img)
    raw_meds = smart_parse(text)
    validated_meds = validate_and_correct_medicines(raw_meds)
    final_names = [m["corrected"] for m in validated_meds if m["valid"]]
    
    result = {
        "medicine_names": final_names, "validated_medicines": validated_meds, "raw_extracted": raw_meds,
        "count": len(final_names), "raw_count": len(raw_meds), "api_time": round(api_time, 2),
        "total_time": round(time.time() - start_total, 2), "cache": False, "model": MODEL_NAME, "db_size": len(MEDICINES_DB)
    }
    
    cache_file = CACHE_DIR / f"{cache_key(image_bytes)}.json"
    if cache_file.exists(): cache_file.unlink()
    
    save_cache(image_bytes, result)
    return result

def extract_from_url(url: str) -> dict:
    return extract(load_image_from_url(url))
