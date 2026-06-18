import base64
import urllib.request
import json

diagrams = {
    "software_architecture.png": """graph TB
    subgraph "Frontend Applications (Flutter)"
        A[Roshetety Patient App]
        B[APMS Staff Dashboard]
    end
    
    subgraph "Backend API Gateway (Node.js)"
        C[Express REST API]
        D[WebSocket Server]
        E[Auth & Middleware]
    end
    
    subgraph "AI Microservices (Python)"
        F[OCR & LLM Service]
        G[XGBoost Forecasting]
    end
    
    subgraph "Data Storage"
        H[(PostgreSQL DB)]
    end
    
    subgraph "Hardware Layer"
        I[Arduino Mega Controller]
        J[Robotic Dispensing Arm]
    end
    
    A -->|HTTP| C
    B -->|HTTP| C
    A -.->|wss://| D
    B -.->|wss://| D
    C --> E
    E --> F
    E --> G
    C -->|SQL| H
    C -->|JSON via Serial| I
    I -->|Stepper Pulses| J
""",
    "layered_architecture.png": """graph TD
    subgraph "1. Presentation Layer (Client)"
        UI[Flutter UI Widgets]
        BLoC[State Management / BLoC]
    end
    
    subgraph "2. Application Layer (API Gateway)"
        Routing[Express Routers]
        Controllers[Business Logic Controllers]
        Auth[JWT Authorization]
    end
    
    subgraph "3. Service Layer (Microservices)"
        AI[Python AI/ML Services]
        Hardware[Serial Communication Service]
    end
    
    subgraph "4. Data Access Layer (DAL)"
        ORM[pg-promise / DB Pool]
    end
    
    subgraph "5. Data & Physical Layer"
        DB[(PostgreSQL Database)]
        Robot[Physical Robotic Arm]
    end
    
    UI -->|Events| BLoC
    BLoC -->|HTTP Requests| Routing
    Routing --> Auth
    Auth --> Controllers
    Controllers --> ORM
    Controllers --> AI
    Controllers --> Hardware
    ORM -->|SQL| DB
    Hardware -->|Serial| Robot
""",
    "staff_use_cases.png": """flowchart LR
    %% Actors
    PM(["👤 Pharmacy Manager"])
    PS(["👤 Pharmacy Staff"])
    
    %% Use Cases
    UC1([Process Digital Prescriptions])
    UC2([Scan Medicine Barcodes])
    UC3([Dispatch Robotic Arm])
    UC4([View AI Demand Forecasts])
    UC5([Manage Inventory & Excel Sync])
    UC6([Handle OTC Walk-in Sales])
    
    %% Relationships
    PM --- UC1
    PM --- UC3
    PM --- UC4
    PM --- UC5
    
    PS --- UC1
    PS --- UC2
    PS --- UC6
""",
    "inventory_sequence.png": """sequenceDiagram
    actor Staff
    participant App as APMS Dashboard
    participant API as Node.js Server
    participant DB as PostgreSQL
    participant WS as WebSocket Server

    Staff->>App: Submits CSV / Excel Import
    App->>API: POST /inventory/upload (multipart/form-data)
    API->>API: Parse CSV and Validate Schema
    API->>DB: Bulk Insert/Update Medicines (Transaction)
    DB-->>API: Success (Rows Affected)
    API->>WS: Broadcast EVENT_INVENTORY_SYNC
    WS-->>App: Trigger UI Refresh
    API-->>App: 200 OK (Import Successful)
    App-->>Staff: Display Success Toast
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
