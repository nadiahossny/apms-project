import base64
import urllib.request
import json

diagrams = {
    "design_system.png": """graph TD
    subgraph "Typography Strategy"
        font["Primary Font: Inter (English) / Cairo (Arabic)"]
        weights["Weights: Regular (400), Medium (500), Bold (700)"]
    end
    
    subgraph "Color Palette Tokens"
        Primary["Primary Blue<br/>#02569B"]:::colorPrim
        Secondary["Secondary Teal<br/>#0D9488"]:::colorSec
        Background["Background Gray<br/>#F3F4F6"]:::colorBg
        TextCol["Main Text<br/>#1F2937"]:::colorText
        Alert["Alert Red<br/>#EF4444"]:::colorAlert
    end
    
    subgraph "Core UI Components"
        Cards["Elevated Cards (Soft Shadows)"]
        Buttons["Rounded Action Buttons"]
        Inputs["Outlined Text Fields with Icons"]
        Tables["Data Tables with Pagination"]
        Sidebar["Collapsible Navigation Sidebar"]
    end

    classDef colorPrim fill:#02569B,color:#FFF,stroke:#FFF;
    classDef colorSec fill:#0D9488,color:#FFF,stroke:#FFF;
    classDef colorBg fill:#F3F4F6,color:#000,stroke:#CCC;
    classDef colorText fill:#1F2937,color:#FFF,stroke:#FFF;
    classDef colorAlert fill:#EF4444,color:#FFF,stroke:#FFF;
""",
    "ai_microservices.png": """graph TD
    subgraph "Client Applications"
        UI[APMS Staff Dashboard]
    end

    subgraph "API Gateway (Node.js)"
        Router[AI Proxy Router]
    end

    subgraph "AI Microservices Layer (Python)"
        subgraph "Predictive Analytics (:5000)"
            XGB[XGBoost Model]
            Forecasting[Demand Forecasting Engine]
            Expiry[Expiry Risk Predictor]
            XGB --> Forecasting & Expiry
        end

        subgraph "OCR Extraction (:5001)"
            FastAPI[FastAPI Server]
            GLM[Ollama: glm-ocr VLM]
            Fuzzy[Fuzzy String Matching DB]
            FastAPI --> GLM
            GLM --> Fuzzy
        end

        subgraph "Chatbot & NLP (:8000)"
            Lang[LangChain Agent]
            Groq[Groq API: LLaMA 3.3]
            Lang --> Groq
        end
    end

    subgraph "Database"
        DB[(PostgreSQL)]
    end

    UI -->|HTTP Requests| Router
    Router -->|Proxy Request| Forecasting
    Router -->|Upload Image| FastAPI
    Router -->|Chat Message| Lang
    
    Forecasting -.->|Read Historical Data| DB
    Fuzzy -.->|Query Medicine Dictionary| DB
    Lang -.->|Execute SQL Query| DB
    
    classDef api fill:#68a063,color:#fff,stroke:#3c873a,stroke-width:2px;
    classDef ai fill:#3776ab,color:#fff,stroke:#ffd43b,stroke-width:2px;
    classDef ext fill:#444,color:#fff,stroke:#222,stroke-width:2px;
    
    class Router api;
    class XGB,Forecasting,Expiry,FastAPI,GLM,Fuzzy,Lang ai;
    class Groq ext;
"""
}

for filename, code in diagrams.items():
    state = {
        "code": code,
        "mermaid": {"theme": "default"}
    }
    json_state = json.dumps(state).encode("utf-8")
    base64_string = base64.urlsafe_b64encode(json_state).decode("ascii")
    
    url = f"https://mermaid.ink/img/{base64_string}?type=png&bgColor=!white"
    
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        with urllib.request.urlopen(req) as response, open(filename, 'wb') as out_file:
            data = response.read()
            out_file.write(data)
        print(f"Image {filename} saved successfully.")
    except Exception as e:
        print(f"Error fetching {filename}: {e}")
