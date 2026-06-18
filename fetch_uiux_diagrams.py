import base64
import urllib.request
import json
import urllib.parse

diagrams = {
    "uiux_user_journey.png": """sequenceDiagram
    autonumber
    actor Patient
    participant Roshetety as Roshetety App (Mobile)
    participant APMS as APMS Staff Dashboard
    participant Robot as Robotic Arm

    Patient->>Roshetety: Opens App (Arabic/English UI)
    Note over Patient,Roshetety: Frictionless HCI: Camera Integration
    Patient->>Roshetety: Scans Prescription via Camera (OCR)
    Roshetety-->>Patient: Returns extracted medicines
    Patient->>Roshetety: Confirms and Submits Order
    Note over Roshetety,APMS: Visibility of System Status
    Roshetety->>APMS: Real-time WebSocket Alert (New Order)
    APMS->>APMS: Staff reviews & links items
    APMS->>Robot: Dispatch Pick Sequence Command
    Robot-->>APMS: Dispensing completed (ACK)
    APMS->>Roshetety: Push Status Update: "READY"
    Roshetety-->>Patient: Notification to collect medicines
""",
    "uiux_navigation_wireframe.png": """graph TD
    %% Styling
    classDef layout fill:#F0F4F8,stroke:#4A90D9,stroke-width:2px,color:#2C3E50;
    classDef sidebar fill:#004187,stroke:#004187,stroke-width:2px,color:#FFFFFF;
    classDef kpi fill:#FFFFFF,stroke:#0D9488,stroke-width:2px,color:#000000;
    classDef chart fill:#FFFFFF,stroke:#7C3AED,stroke-width:2px,color:#000000;
    classDef action fill:#FFFFFF,stroke:#DC2626,stroke-width:2px,color:#000000;

    subgraph "APMS Desktop Layout Strategy"
        direction LR
        Sidebar[Sidebar Navigation<br/>Width: 210px]:::sidebar --> Content[Main Content Area<br/>Responsive Layout]:::layout
    end

    subgraph "Main Content (Dashboard View)"
        direction TB
        KPI[KPI Cards: Stock Value, Pending Rx, Expiring]:::kpi
        Charts[Interactive Revenue & Trend Charts]:::chart
        Action[Stock Action Items: Low Stock, Expiring]:::action
        
        KPI --> Charts
        Charts --> Action
    end
    
    Content -.-> |Renders| KPI
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
