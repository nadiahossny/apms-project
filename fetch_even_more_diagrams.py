import base64
import urllib.request
import json

diagrams = {
    "er_diagram.png": """erDiagram
    USERS ||--o{ PRESCRIPTIONS : creates
    USERS ||--o{ INVOICES : manages
    MEDICINES ||--o{ PRESCRIPTION_ITEMS : contains
    MEDICINES ||--o{ INVENTORY_LOGS : tracks
    PRESCRIPTIONS ||--o{ PRESCRIPTION_ITEMS : includes
    INVOICES ||--o{ INVOICE_ITEMS : includes
    MEDICINES ||--o{ INVOICE_ITEMS : sold_as
    
    USERS {
        uuid id PK
        string name
        string role
        string email
    }
    MEDICINES {
        uuid id PK
        string name
        int stock
        float price
        date expiry_date
    }
    PRESCRIPTIONS {
        uuid id PK
        uuid patient_id FK
        string status
        string image_url
    }
""",
    "hardware_integration.png": """flowchart TD
    A[Staff Submits Order] --> B[Node.js Gateway]
    B --> C[Robot Router]
    C --> D[Format Pick Sequence JSON]
    D --> E[USB Serial Port]
    E -->|Baud 9600| F[Arduino Mega / CNC Shield]
    F --> G[Parse JSON Sequence]
    G --> H[Drive Stepper Motors X/Y/Z]
    H --> I[Activate Electromagnet/Gripper]
    I --> J{Drop successful?}
    J -->|Yes| K[Send ACK via Serial]
    J -->|No| L[Send ERROR via Serial]
    K --> M[Node.js updates Database]
    M --> N[Notify Frontend via WebSocket]
""",
    "ai_forecasting.png": """flowchart LR
    A[(PostgreSQL DB)] -->|Historical Sales| B[Data Preprocessing]
    B --> C[Feature Engineering<br/>Time, Seasonality]
    C --> D[XGBoost Regressor Model]
    D --> E[Generate Next-Month Forecast]
    E --> F[Flask AI Service API]
    F --> G[APMS Dashboard View]
""",
    "websocket_sequence.png": """sequenceDiagram
    participant F as Frontend (Flutter Staff/Patient)
    participant WS as Node.js WebSocket
    participant API as Express Router
    participant DB as PostgreSQL

    F->>WS: Connect & Authenticate (JWT)
    WS-->>F: Connection Established
    F->>API: POST /prescriptions (New Order)
    API->>DB: Insert Prescription
    API->>WS: Broadcast EVENT_NEW_ORDER
    WS-->>F: Real-time UI Update (Dashboard)
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
