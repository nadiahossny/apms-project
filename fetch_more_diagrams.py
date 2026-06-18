import base64
import urllib.request
import json

diagrams = {
    "use_case_diagram.png": """graph TB
    subgraph "Roshetety Patient App"
        P[Patient]
        P -->|Submit Prescription| OCR[OCR Scan Prescription]
        P -->|Manual Entry| ME[Manual Medicine Entry]
        P -->|Check Availability| CA[Check Stock]
        P -->|Track Order| OT[Real-time Order Tracking]
        P -->|Chat| PC[Chat with Pharmacy]
    end

    subgraph "APMS Staff Dashboard"
        M[Manager]
        S[Staff]
        M -->|Login| AL[Authenticate]
        S -->|Login| AL
        
        M -->|Manage Inventory| IM[Inventory CRUD]
        S -->|Scan Barcodes| BC[Barcode Scanning]
        M -->|Import Excel| EI[Excel Import]
        
        M -->|Manage Invoices| IV[Invoice CRUD]
        M -->|Extract PDF| PE[PDF Extraction]
        
        M -->|Manage Prescriptions| PM[Prescription Workflow]
        S -->|Link Items| LI[Link Medicine to Rx]
        M -->|Checkout Rx| CO[Checkout & Complete]
        S -->|OTC Sale| OTC[OTC Walk-in Sale]
        
        M -->|Control Robot| RC[Robot Dispatch]
        
        M -->|AI Center| AI[AI Command Center]
        M -->|Chat with AI| CH[AI Chatbot]
    end
""",
    "user_personas.png": """mindmap
  root((System Users))
    Dr. Ahmed (Manager, 45)
      Needs
        Inventory oversight
        Financial reports
        AI recommendations
      Pain Points
        Manual stock checking
        Expired medicines
    Mariam (Staff, 28)
      Needs
        Fast interface
        Barcode scanning
        Easy Rx processing
      Pain Points
        Complex interfaces
        Illegible handwriting
    Khaled (Patient, 35)
      Needs
        Quick home submission
        Real-time tracking
        Arabic interface
      Pain Points
        Waiting in line
        Stock uncertainty
""",
    "order_processing_flow.png": """flowchart TD
    A([Patient submits via Roshetety]) --> B{OCR or Manual?}
    B -->|OCR| C[Extract medicines via OCR Service]
    B -->|Manual| D[User enters medicine names]
    C --> E[Check stock availability]
    D --> E
    E --> F{All available?}
    F -->|No| G[Show unavailable items]
    F -->|Yes| H[Create prescription: PENDING]
    H --> I[Staff dashboard WebSocket alert]
    I --> J[Staff reviews & links items]
    J --> K{Linking complete?}
    K -->|No| M[Mark PARTIALLY_DISPENSED]
    K -->|Yes| N[Ready for checkout]
    N --> O[Staff clicks Checkout]
    O --> P[Stock deducted from DB]
    P --> Q[Robot dispatch initiated]
    Q --> R[Robot picks medicines]
    R --> S{Success?}
    S -->|Yes| T([Status: READY])
    S -->|No| U([Retry / Manual])
    T --> V[Patient notified via App]
""",
    "ocr_pipeline_flow.png": """flowchart TD
    A[Input Image] --> B[Preprocess Image]
    B --> C[Pass 1: Ollama glm-ocr]
    C --> D[Extract Raw Text]
    D --> E[Pass 2: Medicine DB Matching]
    E --> F[Fuzzy String Matching]
    F --> G{Found in DB?}
    G -->|Yes| H[Return validated medicine]
    G -->|No| I[Return original text]
    H --> J{Score > threshold?}
    J -->|Yes| K([Accept correction])
    J -->|No| L([Flag for manual review])
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
