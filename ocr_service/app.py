from fastapi import FastAPI, UploadFile, File, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from typing import List, Optional
import time
import io
import base64
from PIL import Image

<<<<<<< HEAD
from ocr_core import extract, extract_from_url, search_medicine, GLM_MODEL_NAME
import ocr_core

app = FastAPI(title="Medicine OCR API", version="15.0 - AI Team Updates")
=======
from ocr_core import extract, extract_from_url, smart_medicine_search, MEDICINES_DB, MEDICINES_LIST

app = FastAPI(title="Medicine OCR API", version="14.0 - Bulletproof Flat Match")
>>>>>>> c4340b6b1d5f883c781339aeb4c4f42c3e15a927

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_credentials=True,
    allow_methods=["*"], allow_headers=["*"], expose_headers=["*"],
)

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    return JSONResponse(status_code=500, content={"error": str(exc)})

class ImageURL(BaseModel):
    url: str

class ContentItem(BaseModel):
    type: str
    text: Optional[str] = None
    image_url: Optional[ImageURL] = None

class Message(BaseModel):
    role: str
    content: List[ContentItem]

class ChatRequest(BaseModel):
    model: str
    messages: List[Message]
    max_tokens: Optional[int] = 2048
    temperature: Optional[float] = 0.0

class Base64Image(BaseModel):
    image: str = Field(..., description="Paste base64 starting with data:image/jpeg;base64,...")

class MedicineCheck(BaseModel):
    name: str

@app.post("/v1/chat/completions")
async def chat(req: ChatRequest):
    image_url = None
    for msg in req.messages:
        for item in msg.content:
            if item.type == "image_url" and item.image_url:
                image_url = item.image_url.url
    if not image_url:
        raise HTTPException(status_code=400, detail="No image_url provided")
    
    try:
        result = extract_from_url(image_url)
<<<<<<< HEAD
        content_text = "\n".join(result.get("medicine_names", [])) if result.get("medicine_names") else "No medicines detected."
        
        medications = result.get("medications", [])
        corrections = [m for m in medications if m.get("search_confidence") in ["high", "medium"]]
        if corrections:
            content_text += "\n\nDB Matched:\n"
            for c in corrections:
                original = c.get("raw_ocr_text", "")
                corrected = c.get("matched_name", "")
                score = c.get("score", 0)
                if original and original.lower() != corrected.lower():
                    content_text += f"- {original} -> {corrected} (Score: {score})\n"
        
        return {
            "id": "ocr-med-001", "object": "chat.completion", "created": int(time.time()),
            "model": req.model or GLM_MODEL_NAME,
=======
        content_text = "\n".join(result["medicine_names"]) if result["medicine_names"] else "No medicines detected."
        
        corrections = [m for m in result.get("validated_medicines", []) if m.get("valid")]
        if corrections:
            content_text += "\n\nDB Matched:\n"
            for c in corrections:
                if c["original"] != c["corrected"]:
                    method = c.get("method", "unknown")
                    score = c.get("score", 0)
                    content_text += f"- {c['original']} -> {c['corrected']} (Score: {score})\n"
        
        return {
            "id": "ocr-med-001", "object": "chat.completion", "created": int(time.time()),
            "model": req.model or "glm-ocr:latest",
>>>>>>> c4340b6b1d5f883c781339aeb4c4f42c3e15a927
            "choices": [{"index": 0, "message": {"role": "assistant", "content": content_text}, "finish_reason": "stop"}],
            "meta": result
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/upload")
async def upload_file(file: UploadFile = File(...)):
    try:
        img_bytes = await file.read()
        if len(img_bytes) > 10 * 1024 * 1024:
            raise HTTPException(status_code=413, detail="Max 10MB allowed.")
        return extract(img_bytes)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/upload/base64")
async def upload_base64(data: Base64Image):
    try:
        image_data = data.image
        if len(image_data) < 100:
            raise HTTPException(status_code=400, detail="Base64 string is too short.")
        if "," in image_data:
            image_data = image_data.split(",")[1]
        img_bytes = base64.b64decode(image_data.strip().replace('\n', ''))
        if len(img_bytes) > 10 * 1024 * 1024:
            raise HTTPException(status_code=413, detail="Image too large.")
        return extract(img_bytes)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/validate/medicine")
async def validate_medicine(data: MedicineCheck):
<<<<<<< HEAD
    res = search_medicine(data.name)
    meds = res.get("medications", [])
    if meds and meds[0].get("score", 0) >= 60:
        return {"original": data.name, "corrected": meds[0]["matched_name"], "valid": True, "score": meds[0]["score"], "method": meds[0].get("search_confidence", "none")}
    return {"original": data.name, "corrected": data.name, "valid": False, "score": 0, "method": "none"}

@app.get("/search/medicine")
async def search_medicine_endpoint(query: str):
    query_lower = query.lower()
    matches = [m for m in ocr_core._cleaned_names if query_lower in m.lower()]
=======
    return smart_medicine_search(data.name)

@app.get("/search/medicine")
async def search_medicine(query: str):
    query_lower = query.lower()
    matches = [m for m in MEDICINES_LIST if query_lower in m.lower()]
>>>>>>> c4340b6b1d5f883c781339aeb4c4f42c3e15a927
    return {"query": query, "results": matches[:20], "count": len(matches)}

@app.get("/")
def home():
<<<<<<< HEAD
    return {"status": "running", "model": GLM_MODEL_NAME, "docs": "/docs", "db_size": len(ocr_core._cleaned_names_set)}

@app.get("/health")
def health():
    return {"status": "healthy", "model": GLM_MODEL_NAME, "medicines_db_size": len(ocr_core._cleaned_names_set)}

# ── INVOICE OCR ENDPOINT ───────────────────────────────────────────────────────
@app.post("/invoice/upload")
async def invoice_upload(request: Request):
    time_start = time.time()
    try:
        img_bytes = await request.body()
        if len(img_bytes) > 10 * 1024 * 1024:
            raise HTTPException(status_code=413, detail="Max 10MB allowed.")

        # Use ollama with invoice-specific prompt
        from ocr_core import preprocess_image, GLM_MODEL_NAME, ollama
        import re

        img = preprocess_image(img_bytes)
        response = ollama.chat(
            model=GLM_MODEL_NAME,
            messages=[
                {
                    "role": "system",
                    "content": (
                        "You are an invoice OCR assistant. Extract ALL line items from this supplier invoice image. "
                        "For each line item, return the medicine name, quantity, and unit cost/price. "
                        "Also extract: invoice/fatoora number, supplier/company name, invoice date, total amount, and discount if visible. "
                        "Return ONLY valid JSON with this structure:\n"
                        "{\n"
                        '  "fatoora_number": "INV-123",\n'
                        '  "company_name": "Supplier Name",\n'
                        '  "invoice_date": "2026-01-15",\n'
                        '  "total_amount": 1250.50,\n'
                        '  "total_discount": 50.00,\n'
                        '  "items": [\n'
                        '    {"name": "Medicine Name", "quantity": 100, "unit_cost": 15.50}\n'
                        "  ]\n"
                        "}\n"
                        "If a field is not visible, use null. Do NOT include any text outside the JSON."
                    ),
                },
                {
                    "role": "user",
                    "content": "Extract invoice data from this image.",
                    "images": [img],
                },
            ],
            options={
                "temperature": 0.0,
                "num_ctx": 1024,
                "num_predict": 500,
                "num_thread": 8,
                "top_k": 50,
                "top_p": 0.9,
                "repeat_penalty": 1.1,
            },
        )

        raw_text = response["message"]["content"].strip()
        # Try to parse JSON from the response
        result = {"raw_text": raw_text}

        # Extract JSON from markdown code block if present
        json_match = re.search(r'```(?:json)?\s*([\s\S]*?)```', raw_text)
        if json_match:
            json_str = json_match.group(1).strip()
        else:
            json_str = raw_text

        try:
            parsed = json.loads(json_str)
            if isinstance(parsed, dict):
                result["fatoora_number"] = parsed.get("fatoora_number")
                result["company_name"] = parsed.get("company_name")
                result["invoice_date"] = parsed.get("invoice_date")
                result["total_amount"] = parsed.get("total_amount", 0)
                result["total_discount"] = parsed.get("total_discount", 0)
                raw_items = parsed.get("items", [])
                # Validate and correct medicine names using existing DB
                validated_items = []
                from ocr_core import search_medicine
                for item in raw_items:
                    if isinstance(item, dict) and item.get("name"):
                        name = item["name"]
                        res = search_medicine(name)
                        meds = res.get("medications", [])
                        valid = meds and meds[0].get("score", 0) >= 60
                        corrected_name = meds[0]["matched_name"] if valid else name
                        validated_items.append({
                            "name": corrected_name,
                            "original_name": name,
                            "quantity": int(item.get("quantity", 1)),
                            "unit_cost": float(item.get("unit_cost", 0)),
                            "validated": valid,
                        })
                result["items"] = validated_items
                result["items_count"] = len(validated_items)
            else:
                result["items"] = []
                result["items_count"] = 0
        except json.JSONDecodeError:
            # Fallback: try to extract items via heuristic
            result["items"] = []
            result["items_count"] = 0
            result["parse_error"] = "Could not parse JSON from OCR output"

        result["total_time"] = round(time.time() - time_start, 2)
        return result

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
=======
    return {"status": "running", "model": "glm-ocr:latest", "docs": "/docs", "db_size": len(MEDICINES_DB)}

@app.get("/health")
def health():
    return {"status": "healthy", "model": "glm-ocr:latest", "medicines_db_size": len(MEDICINES_DB)}
>>>>>>> c4340b6b1d5f883c781339aeb4c4f42c3e15a927
