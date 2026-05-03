from fastapi import FastAPI, UploadFile, File, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from typing import List, Optional
import time
import io
import base64
from PIL import Image

from ocr_core import extract, extract_from_url, smart_medicine_search, MEDICINES_DB, MEDICINES_LIST

app = FastAPI(title="Medicine OCR API", version="14.0 - Bulletproof Flat Match")

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
    return smart_medicine_search(data.name)

@app.get("/search/medicine")
async def search_medicine(query: str):
    query_lower = query.lower()
    matches = [m for m in MEDICINES_LIST if query_lower in m.lower()]
    return {"query": query, "results": matches[:20], "count": len(matches)}

@app.get("/")
def home():
    return {"status": "running", "model": "glm-ocr:latest", "docs": "/docs", "db_size": len(MEDICINES_DB)}

@app.get("/health")
def health():
    return {"status": "healthy", "model": "glm-ocr:latest", "medicines_db_size": len(MEDICINES_DB)}