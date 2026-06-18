# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  ocr_core.py — Core search engine + GLM-OCR pipeline
#  Pipeline v22 — Sequential Fallback (Stable, No False Positives)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import warnings
warnings.filterwarnings("ignore")

import os
import re
import time
import json as _json
import traceback
from itertools import product as iter_product

import io
import faiss
import jellyfish
import numpy as np
import pandas as pd
import requests
import ollama
from PIL import Image, ImageEnhance, ImageFilter
from rapidfuzz import fuzz, process
from elasticsearch import Elasticsearch
from elasticsearch.exceptions import NotFoundError
from sentence_transformers import SentenceTransformer


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Module-level state
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
_initialized        = False
_ocr_initialized    = False
_es_ready           = False

_df                 = None
_embeddings         = None
_index              = None
_model              = None
_es                 = None

_cleaned_names      = []
_cleaned_names_set  = set()
_name_to_source     = {}
_name_to_row        = {}

_search_cache       = {}

MODEL_NAME          = "all-MiniLM-L6-v2"
SAVE_DIR            = "unified_pipeline_data"
ES_INDEX            = "drugs_unified"
GLM_MODEL_NAME      = "glm-ocr:latest"
RESULTS_DIR         = "/home/demiana/Desktop/emotion/expert-system/results"


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Initialisation
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def init_search():
    global _initialized, _ocr_initialized, _es_ready
    global _df, _embeddings, _index, _model, _es
    global _cleaned_names, _cleaned_names_set, _name_to_source, _name_to_row

    if _initialized: return

    print("   📂 Loading unified database CSV...")
    _df = pd.read_csv(os.path.join(SAVE_DIR, "unified_database.csv"))
    _df["Cleaned"] = _df["Cleaned"].astype(str).str.lower()
    _df["Source"]  = _df["Source"].astype(str).str.lower()

    _cleaned_names     = _df["Cleaned"].tolist()
    _cleaned_names_set = set(_cleaned_names)
    _name_to_source    = _df.set_index("Cleaned")["Source"].to_dict()
    _name_to_row       = _df.set_index("Cleaned").to_dict("index")
    print(f"   ✅ Database loaded: {len(_df)} drugs")

    print("   📂 Loading FAISS index...")
    _embeddings = np.load(os.path.join(SAVE_DIR, "unified_embedding.npy"))
    _index      = faiss.read_index(os.path.join(SAVE_DIR, "unified_faiss.index"))
    print(f"   ✅ FAISS index loaded: {_index.ntotal} vectors")

    print(f"   📂 Loading SentenceTransformer ({MODEL_NAME})...")
    _model = SentenceTransformer(MODEL_NAME)
    _ocr_initialized = True
    print("   ✅ Embedding model loaded")

    print("   📂 Connecting to Elasticsearch...")
    try:
        _es = Elasticsearch("http://localhost:9200")
        try:
            _es.indices.get(index=ES_INDEX)
            print("   ✅ Elasticsearch index already exists")
        except NotFoundError:
            print("   ⏳ Creating Elasticsearch index...")
            _es.indices.create(index=ES_INDEX, body={
                "settings": {
                    "analysis": {
                        "analyzer": {
                            "drug_prefix": {"type": "custom", "tokenizer": "edge_ngram_tokenizer", "filter": ["lowercase"]},
                            "drug_standard": {"type": "custom", "tokenizer": "standard", "filter": ["lowercase", "asciifolding"]}
                        },
                        "tokenizer": {"edge_ngram_tokenizer": {"type": "edge_ngram", "min_gram": 3, "max_gram": 20, "token_chars": ["letter", "digit"]}}
                    }
                },
                "mappings": {
                    "properties": {
                        "name": {"type": "text", "analyzer": "drug_standard", "fields": {"prefix": {"type": "text", "analyzer": "drug_prefix", "search_analyzer": "drug_standard"}}},
                        "source": {"type": "keyword"}, "price": {"type": "keyword"}, "form": {"type": "keyword"}, "company": {"type": "keyword"},
                        "active": {"type": "text", "analyzer": "drug_standard"},
                    }
                }
            })
            for _, row in _df.iterrows():
                _es.index(index=ES_INDEX, document={"name": row["Cleaned"], "source": row["Source"], "price": str(row.get("Price", "")), "form": str(row.get("Form", "")), "company": str(row.get("Company", "")), "active": str(row.get("ActiveIngredient", ""))})
            print("   ✅ Elasticsearch index created and populated")
        _es_ready = True
    except Exception as e:
        print(f"   ⚠️  Elasticsearch not available: {e}")
        _es_ready = False

    os.makedirs(RESULTS_DIR, exist_ok=True)
    _initialized = True
    print("   ✅ Search engine fully initialised")


def _ensure_init():
    if not _initialized: init_search()


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  🆕 PHASE 0: Early Safety Filter
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def is_valid_image_input(image_bytes: bytes) -> bool:
    if not image_bytes or len(image_bytes) < 100: return False
    try:
        img = Image.open(io.BytesIO(image_bytes)); img.verify(); return True
    except Exception: return False


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Helpers & String Cleaners
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def normalize(text: str) -> str:
    if not isinstance(text, str): return ""
    text = text.lower(); text = re.sub(r'[^a-z0-9\s]', ' ', text); text = re.sub(r'\s+', ' ', text).strip(); return text

def get_source(match): return _name_to_source.get(match, "unknown")
def get_row(match): return _name_to_row.get(match, {})

def contains_arabic(text: str) -> bool:
    for char in text:
        if '\u0600' <= char <= '\u06FF': return True
    return False

def has_3_consecutive_letters(text: str) -> bool:
    count = 0
    for char in text:
        if char.isalpha():
            count += 1
            if count >= 3:
                return True
        else:
            count = 0
    return False

_RX_PREFIX_RE = re.compile(r"^R(?:[/\\|.xX]|\s+)", re.IGNORECASE)
def strip_rx_prefix(text: str) -> str:
    if not isinstance(text, str): return ""
    text = text.strip()
    if text.startswith("\u211e"): text = text[1:].lstrip()
    else: text = _RX_PREFIX_RE.sub("", text).lstrip()
    return text

_DOSAGE_FREQ_RE = re.compile(r"^\d+[xXdD]\d+(?:[xXdD]\d+)*$")
def is_dosage_frequency(token: str) -> bool: return bool(_DOSAGE_FREQ_RE.match(token.strip()))
def _remove_dosage_freq_tokens(text: str) -> str: return " ".join([t for t in text.split() if not is_dosage_frequency(t)]).strip()

FORM_WORDS_STRIP = {
    "cream", "gel", "ointment", "lotion", "drop", "drops", "cap", "caps", "capsule", "capsules", "tab", "tabs", "tablet", "tablets", "syrup", "suspension", "solution", "injection", "inj", "iv", "spray", "patch", "sachet", "suppository", "inhaler", "plus", "forte", "retard", "xr", "sr", "od", "bd", "tds", "prn", "sos", "shampoo", "soap", "wash", "serum", "oil", "paint", "mousse", "mask", "swab", "sponge", "powder",
}
def strip_form_words(text: str) -> str:
    if not isinstance(text, str): return ""
    return " ".join([t for t in text.split() if t.lower() not in FORM_WORDS_STRIP]).strip()

NON_DRUG_PRODUCTS = {
    "listerine", "listerine total care", "listerine total care tartar protect", "listerine total care tartar protect mouthwash", "listerine cool mint", "listerine zero", "colgate", "sensodyne", "oral b", "aquafresh", "crest", "scope", "act", "fluoridex", "biotene", "tom's",
}
def is_non_drug_product(name: str) -> bool:
    name_lower = name.lower().strip(); name_norm = normalize(name)
    if name_norm and name_norm in _cleaned_names_set: return False
    if name_lower in NON_DRUG_PRODUCTS: return True
    for blocked in NON_DRUG_PRODUCTS:
        if name_lower.startswith(blocked): return True
    words = name_norm.split()
    for word in words:
        if word in NON_DRUG_PRODUCTS: return True
    return False

# 🆕 Blocklist for short common words that fuzzy search might false-positive on
COMMON_NON_DRUG_WORDS = {
    "eye", "ear", "nose", "lip", "leg", "arm", "toe", "rib", "hip", "jaw",
    "gum", "ray", "tea", "air", "oil", "ice", "ink", "oak", "ale", "ore",
    "axe", "age", "aid", "awe", "eel", "egg", "ego", "elm", "emu", "eve",
    "ewe", "fig", "fin", "fur", "gin", "gym", "hen", "hub", "hue", "ivy",
    "jam", "jar", "jet", "keg", "kid", "kit", "lad", "lap", "law", "lid",
    "log", "mad", "mat", "mud", "mug", "nap", "net", "nod", "nun", "nut",
    "oar", "odd", "orb", "our", "owl", "pad", "pea", "peg", "pen", "pie",
    "pig", "pin", "pit", "pop", "pot", "pup", "rag", "ram", "rat", "red",
    "rig", "rim", "rod", "row", "rub", "rug", "rum", "run", "rye", "sap",
    "saw", "sea", "sew", "sin", "sir", "sit", "ski", "sky", "sob", "son",
    "sow", "soy", "spa", "sue", "sum", "sun", "tab", "tag", "tan", "tar",
    "tin", "toe", "tub", "tug", "urn", "van", "vet", "vow", "wax", "web",
    "wig", "yak", "zoo",
}


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  OCR visual-confusion maps & Variants Generator
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OCR_VISUAL_MAP = {
    'a': [('o', 0.85), ('u', 0.70), ('e', 0.60), ('4', 0.45)], 'b': [('p', 0.90), ('6', 0.75), ('8', 0.90), ('d', 0.40)],
    'c': [('e', 0.65), ('o', 0.70), ('(', 0.60)], 'd': [('o', 0.80), ('cl', 0.95), ('b', 0.40)], 'e': [('c', 0.65), ('o', 0.60), ('a', 0.55)],
    'f': [('t', 0.80), ('7', 0.75)], 'g': [('q', 0.85), ('9', 0.80), ('6', 0.75)], 'h': [('li', 0.95), ('n', 0.60), ('b', 0.50)],
    'i': [('1', 0.98), ('l', 0.96), ('|', 0.90)], 'j': [('i', 0.70), ('y', 0.65)], 'k': [('x', 0.60), ('h', 0.55), ('lc', 0.35)],
    'l': [('1', 0.99), ('i', 0.95), ('t', 0.85), ('|', 0.90)], 'm': [('rn', 0.99), ('nn', 0.90), ('ni', 0.85), ('in', 0.85)],
    'n': [('m', 0.70), ('h', 0.60), ('ri', 0.75)], 'o': [('0', 0.99), ('q', 0.70), ('a', 0.50)], 'p': [('q', 0.75), ('b', 0.70)],
    'q': [('o', 0.75), ('9', 0.80), ('g', 0.75)], 'r': [('n', 0.55), ('v', 0.50)], 's': [('5', 0.99), ('z', 0.65)],
    't': [('7', 0.90), ('f', 0.75), ('l', 0.85), ('+', 0.60)], 'u': [('v', 0.60), ('n', 0.50), ('ii', 0.50)],
    'v': [('u', 0.60), ('y', 0.55)], 'w': [('vv', 0.99), ('uu', 0.45)], 'x': [('k', 0.55), ('z', 0.65), ('><', 0.40)],
    'y': [('v', 0.55), ('j', 0.60)], 'z': [('2', 0.99), ('s', 0.70)], '0': [('o', 0.99)], '1': [('l', 0.99), ('i', 0.98)],
    '2': [('z', 0.99)], '5': [('s', 0.99)], '6': [('g', 0.75), ('b', 0.70)], '7': [('t', 0.90)], '8': [('b', 0.90)], '9': [('g', 0.80), ('q', 0.75)],
}
MULTI_CHAR_MAP = {"rn": ("m", 0.99), "vv": ("w", 0.99), "cl": ("d", 0.95), "li": ("h", 0.95), "nn": ("m", 0.90), "ni": ("m", 0.85), "in": ("m", 0.85), "ri": ("n", 0.75), "tl": ("l", 0.80), "lt": ("t", 0.80), "ii": ("u", 0.65), "ll": ("h", 0.60)}
DRUG_SPECIFIC_MAP = {"mg": ("mq", 0.60), "ml": ("mi", 0.70), "xr": ("xv", 0.60), "sr": ("5r", 0.65), "plus": ("pius", 0.85)}
STOPWORDS = {"and", "or", "the", "with", "for", "in", "of", "to", "a", "an", "is", "by", "on", "at", "from"}
FORM_WORDS = {"tablet", "tablets", "capsule", "capsules", "syrup", "cream", "ointment", "injection", "drop", "drops", "gel", "lotion", "spray", "solution"}

def generate_ocr_variants(text, max_variants=150):
    text = normalize(text)
    if not text: return []
    variants = [(text, 100)]
    for i, char in enumerate(text):
        if char in OCR_VISUAL_MAP:
            for rep, prob in OCR_VISUAL_MAP[char]: variants.append((text[:i] + rep + text[i + 1:], int(prob * 100)))
    for wrong, (correct, prob) in MULTI_CHAR_MAP.items():
        if wrong in text: variants.append((text.replace(wrong, correct), int(prob * 100)))
    for correct_sp, (wrong_sp, prob) in DRUG_SPECIFIC_MAP.items():
        if wrong_sp in text: variants.append((text.replace(wrong_sp, correct_sp), int(prob * 100)))
        if correct_sp in text: variants.append((text.replace(correct_sp, wrong_sp), int(prob * 100)))
    for i in range(len(text)):
        if text[i] == ' ': continue
        variants.append((text[:i] + text[i + 1:], 70))
    for i in range(len(text)):
        if text[i] == ' ': continue
        variants.append((text[:i] + text[i] + text[i:], 65))
    chars = list(text)
    for i in range(len(chars) - 1):
        if chars[i] == ' ' or chars[i + 1] == ' ': continue
        swapped = chars.copy(); swapped[i], swapped[i + 1] = swapped[i + 1], swapped[i]
        variants.append(("".join(swapped), 60))
    words = text.split()
    if 2 <= len(words) <= 4:
        word_variants_list = []
        for w in words:
            local_variants = [(w, 100)]
            for i, char in enumerate(w):
                if char in OCR_VISUAL_MAP:
                    for rep, prob in OCR_VISUAL_MAP[char][:2]: local_variants.append((w[:i] + rep + w[i + 1:], int(prob * 100)))
            seen_w = set(); uniq_w = []
            for v, c in local_variants:
                if v not in seen_w: seen_w.add(v); uniq_w.append((v, c))
            word_variants_list.append(uniq_w[:5])
        combos = list(iter_product(*word_variants_list))
        for combo in combos[:max_variants]:
            combo_text = " ".join([item[0] for item in combo])
            avg_conf = int(sum(item[1] for item in combo) / len(combo))
            if combo_text != text: variants.append((combo_text, avg_conf))
    seen = set(); final_variants = []
    for variant, conf in variants:
        if variant not in seen: seen.add(variant); final_variants.append((variant, conf))
    return final_variants[:max_variants]


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Search Methods
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def exact_match_search(query):
    query = normalize(query)
    if query in _cleaned_names_set: return query, 100, get_source(query)
    return None, 0, None

def prefix_search(query):
    query = normalize(query)
    if len(query) < 4: return None, 0, None
    best_match, best_score, best_source = None, 0, None
    for name in _cleaned_names:
        if name.startswith(query):
            score = min(fuzz.ratio(query, name) * 1.1, 100)
            if score > best_score: best_score, best_match, best_source = score, name, get_source(name)
    return best_match, int(best_score), best_source

def local_substring_search(query):
    query = normalize(query)
    if len(query) < 3: return None, 0, None
    best_match, best_score, best_source = None, 0, None
    for name in _cleaned_names:
        if query in name:
            score = max(int((len(query) / len(name)) * 100), 75)
            if score > best_score: best_score, best_match, best_source = score, name, get_source(name)
    return best_match, int(best_score), best_source

def word_bag_search(query):
    query_words = set(normalize(query).split())
    if len(query_words) < 2: return None, 0, None
    best_match, best_score, best_source = None, 0, None
    for name in _cleaned_names:
        candidate_words = set(name.split())
        common = query_words & candidate_words
        if len(common) == len(query_words):
            coverage = len(query_words) / max(len(candidate_words), 1)
            score = max(int(coverage * 100), 70)
            if score > best_score: best_score, best_match, best_source = score, name, get_source(name)
    return best_match, int(best_score), best_source

def fuzzy_search(query):
    query = normalize(query)
    match = process.extractOne(query, _cleaned_names, scorer=fuzz.ratio, score_cutoff=60)
    if match: name, score, _ = match; return name, int(score), get_source(name)
    return None, 0, None

def phonetic_search(query):
    query_words = normalize(query).split()
    if not query_words: return None, 0, None
    best_match, best_score, best_source = None, 0, None
    for name in _cleaned_names:
        candidate_words = name.split()
        matched_count, total_sim = 0, 0
        for qw in query_words:
            qw_code = jellyfish.metaphone(qw)
            for cw in candidate_words:
                if jellyfish.metaphone(cw) == qw_code: matched_count += 1; total_sim += fuzz.ratio(qw, cw); break
        if matched_count == len(query_words) and matched_count > 0:
            avg_score = total_sim // len(query_words)
            if avg_score > best_score: best_score, best_match, best_source = avg_score, name, get_source(name)
    return best_match, int(best_score), best_source

def elastic_search(query):
    if not _es_ready or _es is None: return None, 0, None
    try:
        result = _es.search(index=ES_INDEX, query={"bool": {"should": [{"match": {"name": {"query": query, "fuzziness": "AUTO"}}}, {"match": {"active": {"query": query, "fuzziness": "AUTO"}}}]}}, size=10)
        hits = result["hits"]["hits"]
        if not hits: return None, 0, None
        best_match, best_score, best_source = None, 0, None
        for hit in hits:
            name = hit["_source"]["name"]; source = hit["_source"].get("source", "unknown"); score = fuzz.ratio(normalize(query), name)
            if score > best_score: best_score, best_match, best_source = score, name, source
        return best_match, int(best_score), best_source
    except Exception: return None, 0, None

def faiss_search(query):
    try:
        q_vec = _model.encode([normalize(query)]).astype("float32")
        D, I = _index.search(q_vec, 5)
        best_match, best_score, best_source = None, 0, None
        for idx in I[0]:
            if idx < 0 or idx >= len(_df): continue
            candidate = _df.iloc[idx]["Cleaned"]; source = _df.iloc[idx]["Source"]; score = fuzz.ratio(normalize(query), candidate)
            if score > best_score: best_score, best_match, best_source = score, candidate, source
        return best_match, int(best_score), best_source
    except Exception as e: print(f"⚠️  faiss_search error: {e}"); return None, 0, None

def ocr_search(query):
    """Smart Fuzzy OCR Search - Capped at 85% to prevent false 100%s"""
    variants = generate_ocr_variants(query)
    best_match, best_score, best_source = None, 0, None
    for variant, variant_conf in variants:
        if variant in _cleaned_names_set:
            score = min(max(int((variant_conf * 0.5) + 50), 75), 85) # 🆕 Capped at 85%
            if score > best_score: best_score, best_match, best_source = score, variant, get_source(variant)
            continue
        match = process.extractOne(variant, _cleaned_names, scorer=fuzz.ratio, score_cutoff=60)
        if match:
            name, base_score, _ = match
            score = (base_score * 0.7) + (variant_conf * 0.3)
            score = max(0, min(score, 100))
            if score > best_score: best_score, best_match, best_source = score, name, get_source(name)
    return best_match, int(best_score), best_source

def smart_fix_ocr_query(text):
    text = normalize(text)
    if not text: return text
    variants = generate_ocr_variants(text)
    variants.sort(key=lambda x: x[1], reverse=True)
    for variant, conf in variants[1:]:
        if variant in _cleaned_names_set: return variant
    return text


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  🔍 PHASE 4: Sequential Fallback Search Engine
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def search_medicine(query, top_k=5):
    _ensure_init()
    original_query = normalize(query)
    if not original_query: return _sanitize({"medications": [], "count": 0, "query": query})

    # CACHE LOOKUP
    if original_query in _search_cache:
        print(f"⚡ Cache HIT for '{original_query}' — returning instantly")
        return _search_cache[original_query]

    # ━━━━━━ STEP 1: Exact Match ━━━━━━
    match, score, source = exact_match_search(original_query)
    if score == 100:
        print(f"🎯 Exact match for {original_query}")
        row = get_row(match)
        result = _sanitize({"medications": [{"matched_name": match, "score": 100, "source": source, "search_confidence": "high", "active_ingredient": row.get("ActiveIngredient", ""), "price": row.get("Price", None), "form": row.get("Form", ""), "company": row.get("Company", "")}], "count": 1, "query": query})
        _search_cache[original_query] = result
        return result

    # ━━━━━━ STEP 2: Smart OCR Fix ━━━━━━
    fixed_query = smart_fix_ocr_query(original_query)
    if fixed_query != original_query:
        match, score, source = exact_match_search(fixed_query)
        if score == 100:
            print(f"🔀 Smart OCR Fix: {original_query} → {fixed_query}")
            row = get_row(match)
            result = _sanitize({"medications": [{"matched_name": match, "score": 85, "source": source, "search_confidence": "high", "active_ingredient": row.get("ActiveIngredient", ""), "price": row.get("Price", None), "form": row.get("Form", ""), "company": row.get("Company", "")}], "count": 1, "query": query})
            _search_cache[original_query] = result
            return result

    # ━━━━━━ STEP 3: Sequential Fallback ━━━━━━
    search_sequence = [
        ("elastic", elastic_search), ("fuzzy", fuzzy_search), ("phonetic", phonetic_search),
        ("faiss", faiss_search), ("ocr", ocr_search), ("prefix", prefix_search),
        ("substring", local_substring_search), ("word_bag", word_bag_search),
    ]

    best_match, best_score, best_source = None, 0, None

    for method_name, method_fn in search_sequence:
        try:
            m_match, m_score, m_source = method_fn(original_query)
            if m_match and m_score > best_score:
                best_match, best_score, best_source = m_match, m_score, m_source
                if best_score >= 85:
                    print(f"✅ Found via {method_name} with score {best_score}")
                    break 
        except Exception as e:
            print(f"⚠️  {method_name} search error: {e}")

    if not best_match or best_score == 0: return _sanitize({"medications": [], "count": 0, "query": query})

    # ━━━━━━ STEP 4: Reject Invalid Matches ━━━━━━
    GENERIC_MATCHES = {"shampoo", "soap", "wash", "lotion", "cream", "gel", "tablet", "tablets", "capsule", "capsules", "syrup", "spray", "solution", "injection", "drops", "wipe", "pad", "swab", "sponge", "mask", "strip"}
    
    def is_invalid_match(m_name):
        if len(m_name) < 3: return True
        if m_name in GENERIC_MATCHES: return True
        if is_non_drug_product(m_name): return True
        # 🆕 Prevent short OCR noise from matching common English words like "eye"
        if m_name in COMMON_NON_DRUG_WORDS:
            print(f"   🚫 Blocked common non-drug word: '{m_name}'")
            return True
        # 🆕 Short query + short match + low score = almost certainly a false positive
        if len(original_query) <= 5 and len(m_name) <= 4 and best_score < 90:
            print(f"   🚫 Blocked short-query false positive: '{original_query}' → '{m_name}' (score {best_score})")
            return True
        # Existing length mismatch check
        if len(original_query) < 5 and len(m_name.split()) > 3:
            print(f"   🚫 Blocked length mismatch: query '{original_query}' vs match '{m_name}'")
            return True
        return False

    if is_invalid_match(best_match):
        print(f"   ⚠️ Rejecting invalid match: '{best_match}'")
        return _sanitize({"medications": [], "count": 0, "query": query})

    # ━━━━━━ STEP 5: Output ━━━━━━
    row = get_row(best_match)
    confidence_str = "high" if best_score >= 85 else ("medium" if best_score >= 60 else "low")

    result = _sanitize({"medications": [{
        "matched_name": best_match, "score": best_score, "source": best_source,
        "search_confidence": confidence_str, "active_ingredient": row.get("ActiveIngredient", ""), 
        "price": row.get("Price", None), "form": row.get("Form", ""), "company": row.get("Company", ""),
    }], "count": 1, "query": query})

    if best_score >= 85: _search_cache[original_query] = result
    return result


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  GLM-OCR PROMPTS & Parser
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SYSTEM_PROMPT = """
<role>
  You are a specialized pharmaceutical OCR engine.
  Your only purpose is to detect and extract English medicine
  (drug) names from handwritten doctor prescription images.
</role>
<context>
  The image is a handwritten doctor prescription that contains
  a MIX of languages and content types:
  LANGUAGES IN THE IMAGE:
    - Medicine names         → written in ENGLISH  (your TARGET)
    - Dosage instructions    → written in ARABIC   (IGNORE)
    - Other notes/labels     → written in ARABIC   (IGNORE)
  OTHER CONTENT TO IGNORE COMPLETELY:
    - Doctor name, title, specialization, clinic, hospital
    - Patient name, age, gender, weight, ID number
    - Date, address, phone number, stamp, signature, barcode
    - Any Arabic script or Arabic characters
    - Any digit or number (doses, quantities, frequencies)
</context>
<strict_extraction_rules>
  EXTRACT ONLY:
    - English medicine or drug names that are physically
      visible and readable in the image you receive.
  SINGLE MEDICINE PER ENTRY:
    - Each object in the 'medicines' array MUST represent EXACTLY ONE medicine.
    - Do NOT combine multiple medicines into a single raw_text or cleaned_name string.
    - If the image contains two different medicines (even on adjacent lines), output TWO separate JSON objects.
  STRIP from each extracted name before returning:
    Remove any of these words if they appear directly before
    or after the drug name:
      cream, gel, ointment, lotion, drops, drop,
      cap, caps, capsule, capsules,
      tab, tabs, tablet, tablets,
      syrup, suspension, solution, emulsion,
      injection, inj, infusion, vial, ampoule,
      spray, inhaler, patch, sachet, suppository,
      powder, granules, forte, plus, compound,
      shampoo, soap, wash, serum, oil, paint, mousse, mask.
    Keep only the core drug name after stripping.
  DO NOT:
    - Output any medicine name that is not visible in the image.
    - Add explanations, notes, or any text outside the JSON.
    - Include the same medicine twice.
  ILLEGIBLE TEXT:
    If a medicine name exists but cannot be read with
    confidence, include it as "illegible_[n]" where n is
    its position index starting from 1.
</strict_extraction_rules>
""".strip()

USER_PROMPT = """
<task>
  1. Look ONLY at the image attached to this message.
  2. Scan the entire prescription image carefully.
  3. Find every English medicine name that is physically
     written in the image — nothing else.
  4. Apply the stripping rules from your instructions to
     remove dosage form words from each name.
  5. Return the result ONLY as the JSON object below.
</task>
<output_format>
  Return a single valid JSON object.
  No markdown fences, no code blocks, no extra text.
  Schema:
  {
    "medicines": [
      {
        "index": <integer starting from 1>,
        "raw_text": "<text exactly as written in the image>",
        "cleaned_name": "<drug name after stripping Rx prefix, dosage-frequency tokens, and form words>",
        "confidence": "<high | medium | low>"
      }
    ],
    "total_found": <integer>,
    "illegible_count": <integer>
  }
  cleaned_name rules (applied in order):
    1. Remove any leading R/ R\\ Rx ℞ R| R. prescription symbol.
    2. Remove dosage-frequency tokens like 1x2, 2X3, 1d2x7 — these
       are NOT drug names; if the whole value is such a token, omit it.
    3. Remove dosage-form words (tablet, capsule, syrup, shampoo, etc.).
    Result should be the bare drug name only.
  confidence:
    high   → clearly legible, unambiguous
    medium → legible but spelling may be approximate
    low    → partially illegible, best-effort reading
  If no English medicine names are found in the image:
  { "medicines": [], "total_found": 0, "illegible_count": 0 }
</output_format>
""".strip()

def _sanitize(obj):
    if isinstance(obj, dict): return {k: _sanitize(v) for k, v in obj.items()}
    if isinstance(obj, list): return [_sanitize(v) for v in obj]
    if isinstance(obj, float): return None if not np.isfinite(obj) else obj
    if isinstance(obj, np.floating): f = float(obj); return None if not np.isfinite(f) else f
    if isinstance(obj, np.integer): return int(obj)
    if isinstance(obj, np.bool_): return bool(obj)
    return obj

def parse_glm_output(raw: str) -> dict:
    if not raw: return {"medicines": [], "total_found": 0, "illegible_count": 0}
    cleaned = re.sub(r"```(?:json)?|```", "", raw).strip()
    cleaned = re.sub(r",\s*([}\]])", r"\1", cleaned)
    def _try_parse(text: str):
        try: return _json.loads(text)
        except _json.JSONDecodeError: return None
    data = _try_parse(cleaned)
    if data is None or "medicines" not in data:
        for m in re.finditer(r'\{.*?\}', cleaned, re.DOTALL):
            candidate = _try_parse(m.group())
            if candidate and "medicines" in candidate: data = candidate; break
    if data is None or "medicines" not in data:
        print(f"⚠️  JSON parse failed.\nRaw:\n{raw[:400]}")
        return {"medicines": [], "total_found": 0, "illegible_count": 0}
    medicines = data.get("medicines", [])
    cleaned_medicines = []
    for item in medicines:
        raw_text = item.get("raw_text", ""); confidence = item.get("confidence", "medium")
        raw_lines = [ln.strip(' -•–—') for ln in raw_text.split('\n') if ln.strip(' -•–—')]
        for line in raw_lines:
            if not line or len(line) < 2: continue
            current_cleaned = strip_rx_prefix(line)
            if not current_cleaned: current_cleaned = strip_form_words(strip_rx_prefix(line))
            current_cleaned = strip_form_words(current_cleaned)
            current_cleaned = re.sub(r"\b\d+\b", "", current_cleaned).strip()
            current_cleaned = _remove_dosage_freq_tokens(current_cleaned)
            if not current_cleaned: continue
            if contains_arabic(current_cleaned): continue
            if len(current_cleaned.replace(" ", "")) < 3: continue
            if current_cleaned.lower() in FORM_WORDS_STRIP: continue
            if is_non_drug_product(current_cleaned): continue
            if not has_3_consecutive_letters(current_cleaned): continue
            if not any(c.isalpha() for c in current_cleaned): continue
            cleaned_medicines.append({"raw_text": line, "cleaned_name": current_cleaned, "confidence": confidence})
    data["total_found"] = len(cleaned_medicines); data["medicines"] = cleaned_medicines
    return data


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  🖼️ PHASE 1 & 🤖 PHASE 2
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def preprocess_image(image_bytes: bytes) -> bytes:
    try:
        img = Image.open(io.BytesIO(image_bytes))
        MIN_LONG_EDGE, MAX_LONG_EDGE = 1600, 2400; w, h = img.size; long_edge = max(w, h)
        if long_edge < MIN_LONG_EDGE:
            scale = MIN_LONG_EDGE / long_edge; img = img.resize((int(w * scale), int(h * scale)), Image.LANCZOS)
        elif long_edge > MAX_LONG_EDGE:
            scale = MAX_LONG_EDGE / long_edge; img = img.resize((int(w * scale), int(h * scale)), Image.LANCZOS)
        img = img.convert("L").convert("RGB")
        img = ImageEnhance.Contrast(img).enhance(1.8); img = ImageEnhance.Sharpness(img).enhance(2.0)
        img = img.filter(ImageFilter.UnsharpMask(radius=2, percent=120, threshold=3))
        buf = io.BytesIO(); img.save(buf, format="JPEG", quality=95); return buf.getvalue()
    except Exception as e: print(f"   ⚠️  Image preprocessing failed: {e}"); return image_bytes

def run_glm_ocr(image_bytes: bytes) -> tuple:
    start = time.time()
    try:
        processed_bytes = preprocess_image(image_bytes)
        response = ollama.chat(model=GLM_MODEL_NAME, messages=[
            {"role": "system", "content": SYSTEM_PROMPT}, {"role": "user", "content": USER_PROMPT, "images": [processed_bytes]}
        ], options={"temperature": 0.0, "num_ctx": 6144, "num_predict": 768, "num_thread": 8, "top_k": 1, "top_p": 1.0, "repeat_penalty": 1.15, "repeat_last_n": 128})
        raw = response["message"]["content"].strip(); parsed = parse_glm_output(raw)

        # 🔄 Auto-Retry Loop
        low_conf_items = [m for m in parsed.get("medicines", []) if m.get("confidence") == "low" and not m["cleaned_name"].startswith("illegible")]
        if low_conf_items:
            low_names = ", ".join(f'"{m["raw_text"]}"' for m in low_conf_items)
            refocus_prompt = f"In the same image, these medicine names were marked low-confidence: {low_names}. Look at those specific areas again very carefully. Return ONLY a JSON array of objects with keys 'raw_text', 'cleaned_name', 'confidence'."
            try:
                resp2 = ollama.chat(model=GLM_MODEL_NAME, messages=[
                    {"role": "system", "content": SYSTEM_PROMPT}, {"role": "user", "content": USER_PROMPT, "images": [processed_bytes]},
                    {"role": "assistant", "content": raw}, {"role": "user", "content": refocus_prompt}
                ], options={"temperature": 0.0, "num_ctx": 4096, "num_predict": 512, "top_k": 1, "top_p": 1.0})
                raw2 = resp2["message"]["content"].strip(); parsed2 = parse_glm_output(raw2)
                if parsed2.get("medicines"):
                    for item2 in parsed2["medicines"]:
                        for item in parsed["medicines"]:
                            if item["raw_text"] == item2.get("raw_text") and item2.get("confidence") != "low":
                                item["cleaned_name"] = item2["cleaned_name"]; item["confidence"] = item2["confidence"]
            except Exception as e2: print(f"   ⚠️  GLM second pass failed: {e2}")

        elapsed = time.time() - start
        print(f"   ✅ GLM-OCR completed in {elapsed:.1f}s  —  {len(parsed.get('medicines', []))} medicines found")
        return parsed, processed_bytes
    except Exception as e:
        elapsed = time.time() - start; print(f"   ❌ GLM-OCR failed in {elapsed:.1f}s: {e}"); traceback.print_exc()
        return {"medicines": [], "total_found": 0, "illegible_count": 0}, image_bytes


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  📦 API Response & Storage
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def _save_result(data: dict):
    try:
        os.makedirs(RESULTS_DIR, exist_ok=True)
        timestamp = int(time.time() * 1000)
        filepath = os.path.join(RESULTS_DIR, f"result_{timestamp}.json")
        with open(filepath, "w", encoding="utf-8") as f: _json.dump(data, f, indent=2, ensure_ascii=False)
    except Exception as e: print(f"   ⚠️ Failed to save result: {e}")

def _process_image_bytes(image_bytes: bytes) -> dict:
    _ensure_init()

    # EARLY SAFETY FILTER
    if not is_valid_image_input(image_bytes):
        print("   🚫 Invalid or corrupt image rejected at input.")
        return _sanitize({"medications": [], "medicine_names": [], "count": 0, "query": "invalid_image", "error": "Invalid image format"})

    ocr_result, _ = run_glm_ocr(image_bytes)
    medicines = ocr_result.get("medicines", [])
    
    if not medicines:
        empty_result = _sanitize({"medications": [], "medicine_names": [], "count": 0, "query": "image_ocr"})
        _save_result(empty_result)
        return empty_result

    final_medications = []

    for med in medicines:
        cleaned_name = med.get("cleaned_name", "")
        if not cleaned_name or cleaned_name.startswith("illegible"): continue

        # 🆕 Skip very short OCR noise (< 4 chars) unless it's an exact DB match
        if len(cleaned_name.replace(" ", "")) < 4:
            _ensure_init()
            if normalize(cleaned_name) not in _cleaned_names_set:
                print(f"   🚫 Skipping short OCR noise: '{cleaned_name}'")
                continue

        # 🆕 Skip if the cleaned name is a common non-drug word
        if cleaned_name.lower().strip() in COMMON_NON_DRUG_WORDS:
            print(f"   🚫 Skipping common non-drug word from OCR: '{cleaned_name}'")
            continue

        search_result = search_medicine(cleaned_name)

        if search_result and search_result.get("medications"):
            match_data = search_result["medications"][0]
            match_data["glm_confidence"] = med.get("confidence", "medium")
            match_data["raw_ocr_text"] = med.get("raw_text", "")
            final_medications.append(match_data)
        else:
            # Return as a low confidence drug for the user to see
            final_medications.append({
                "matched_name": cleaned_name, "score": 0, "source": "unknown",
                "search_confidence": "low", "active_ingredient": "", "price": None,
                "form": "", "company": "", "glm_confidence": med.get("confidence", "low"),
                "raw_ocr_text": med.get("raw_text", ""),
            })

    medicine_names = [
        m["matched_name"] for m in final_medications 
        if m.get("matched_name") and m.get("search_confidence") in ["high", "medium"]
    ]

    final_output = _sanitize({
        "medications": final_medications,
        "medicine_names": medicine_names,
        "count": len(final_medications),
        "query": "image_ocr"
    })

    _save_result(final_output)
    return final_output

def extract(image_bytes: bytes) -> dict:
    return _process_image_bytes(image_bytes)

def extract_from_url(url: str) -> dict:
    try:
        response = requests.get(url, timeout=15); response.raise_for_status()
        return _process_image_bytes(response.content)
    except Exception as e:
        print(f"❌ Failed to download image from URL: {e}")
        return _sanitize({"medications": [], "medicine_names": [], "count": 0, "query": url, "error": str(e)})