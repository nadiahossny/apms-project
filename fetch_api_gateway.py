import base64
import urllib.request
import json

mermaid_code = """graph TD
    %% Clients
    subgraph "Clients"
        APMS[APMS Staff App]
        ROSH[Roshetety Patient App]
    end

    %% API Gateway Layer
    subgraph "API Gateway (Node.js/Express :4000)"
        MW[Global Middleware:<br>CORS, JSON Parser, Zod Validator]
        JWT[JWT Authentication & Role Guard]
        
        subgraph "Express Routers"
            direction TB
            AuthR[Auth Router]
            MedR[Medicines Router]
            InvR[Invoices Router]
            RxR[Prescriptions Router]
            RobR[Robot Router]
            AIR[AI Proxy Router]
            RepR[Reports Router]
            PubR[Public/Rate-limited Router]
        end
        
        WS[WebSocket Server Singleton]
        DBPool[pg Connection Pool]
    end

    %% Downstream
    subgraph "Downstream Dependencies"
        DB[(PostgreSQL Database)]
        AI_SVC[Python AI Services]
        ROBOT[Robotic Arm via Serial Port]
    end

    %% Request Flow
    APMS -->|HTTP Requests| MW
    ROSH -->|HTTP Requests| MW
    
    MW --> PubR
    MW --> JWT
    JWT --> AuthR
    JWT --> MedR
    JWT --> InvR
    JWT --> RxR
    JWT --> RobR
    JWT --> AIR
    JWT --> RepR

    %% Internal Data Flow
    AuthR & MedR & InvR & RxR & RepR & PubR --> DBPool
    DBPool -->|SQL Queries| DB
    
    AIR -->|HTTP Proxy| AI_SVC
    RobR -->|JSON Commands| ROBOT

    %% WebSockets Flow
    APMS <-->|WebSocket Events| WS
    ROSH <-->|WebSocket Events| WS
    ROBOT -.->|Serial ACK| WS
    DBPool -.->|DB Trigger/Updates| WS

    %% Styling
    classDef gateway fill:#68a063,stroke:#3c873a,stroke-width:2px,color:#fff;
    classDef client fill:#02569B,stroke:#0175C2,stroke-width:2px,color:#fff;
    classDef downstream fill:#444,stroke:#222,stroke-width:2px,color:#fff;
    classDef router fill:#3776ab,stroke:#ffd43b,stroke-width:1px,color:#fff;
    
    class MW,JWT,WS,DBPool gateway;
    class APMS,ROSH client;
    class DB,AI_SVC,ROBOT downstream;
    class AuthR,MedR,InvR,RxR,RobR,AIR,RepR,PubR router;
"""

state = {
  "code": mermaid_code,
  "mermaid": {"theme": "default"}
}

json_state = json.dumps(state).encode("utf-8")
base64_string = base64.urlsafe_b64encode(json_state).decode("ascii")

url = f"https://mermaid.ink/img/{base64_string}?type=png&bgColor=!white"

req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req) as response, open('api_gateway_architecture.png', 'wb') as out_file:
        data = response.read()
        out_file.write(data)
    print("Image saved successfully.")
except Exception as e:
    print(f"Error: {e}")
