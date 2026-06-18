import base64
import urllib.request
import json

diagrams = {
    "deployment_architecture.png": """graph TD
    subgraph "Public Internet"
        P[Patient Mobile Device<br/>Roshetety App]
    end

    subgraph "Pharmacy Local Network (On-Premise)"
        subgraph "Staff Workstation"
            S[Staff Desktop / Web<br/>APMS Dashboard]
        end
        
        subgraph "Local Server Engine"
            direction TB
            Node[Node.js API Gateway]
            DB[(PostgreSQL)]
            AI[Python Microservices]
            
            Node <--> DB
            Node <--> AI
        end
        
        subgraph "Hardware Assembly"
            Mega[Arduino Mega]
            Arm[Robotic Arm Mechanics]
            Mega --> Arm
        end
        
        Node -- USB Serial --> Mega
    end

    P -- HTTP/WSS --> Node
    S -- HTTP/WSS --> Node
""",
    "flutter_architecture.png": """graph TD
    subgraph "Flutter App Architecture (Clean Architecture Pattern)"
        direction TB
        subgraph "UI Layer (Presentation)"
            UI[Widgets & Screens]
            SM[State Management<br/>Provider / BLoC]
            UI <-->|Events / States| SM
        end

        subgraph "Domain Layer"
            Models[Data Models & Entities]
        end

        subgraph "Data Layer (Repositories)"
            Repo[Repository Pattern]
            API_C[API Client<br/>Dio / HTTP / ws]
            
            Repo --> Models
            Repo --> API_C
        end

        SM -->|Method Calls| Repo
        Repo -->|Parsed Entities| SM
    end
    
    API_C <-->|JSON Stream| Backend[External Backend]
""",
    "security_auth_flow.png": """sequenceDiagram
    participant User
    participant App as Frontend App
    participant API as Node.js Gateway
    participant DB as PostgreSQL

    User->>App: Enters Credentials (Email + Password)
    App->>API: POST /auth/login {email, password}
    API->>DB: Query User by Email
    DB-->>API: Return User Hash & Role
    API->>API: bcrypt.compare(hash)
    alt Invalid Credentials
        API-->>App: 401 Unauthorized
        App-->>User: Show Error Display
    else Valid Credentials
        API->>API: Sign JWT with Role (Staff/Manager)
        API-->>App: 200 OK + { token, user_data }
        App->>App: Store Token securely
        App-->>User: Navigate to Dashboard
    end

    Note over App,API: Subsequent Protected Requests
    App->>API: GET /api/data (Header: Bearer Token)
    API->>API: Verify JWT & Validate Role Guards
    API-->>App: 200 OK (Data Payload)
""",
    "google_sheets_bridge.png": """flowchart TD
    A[Node.js Background Worker] -->|Polls every 15s| B[Fetch Google Sheets CSV Export]
    B --> C{New Entries Found?}
    C -->|No| D[Idle / Wait]
    C -->|Yes| E[Parse CSV Rows into JSON]
    E --> F[Validate Schema / Sanitize]
    F --> G{Is Valid?}
    G -->|No| H[Log Error / Flag Invalid Entry]
    G -->|Yes| I[Sync Data to PostgreSQL DB]
    I --> J[Broadcast WebSocket Event]
    J --> K[Real-time APMS Dashboard Update]
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
