import base64
import urllib.request
import json

mermaid_code = """graph TB
    subgraph "Frontend"
        APMS[APMS Flutter Staff]
        ROSH[Roshetety Patient App]
    end

    subgraph "Backend API Gateway"
        EX[Node.js Express Server]
        WS[WebSocket Server]
    end

    subgraph "Data Storage"
        PG[(PostgreSQL)]
    end

    subgraph "Microservices"
        AI[AI Dashboard :5000]
        OCR[OCR Service :5001]
        CHAT[AI Chatbot :8000]
    end

    subgraph "Hardware Integrations"
        SERIAL[USB Serial]
        ROBOT[Robotic Arm]
    end

    APMS --> EX
    ROSH --> EX
    APMS -.-> WS
    ROSH -.-> WS
    EX --> PG
    EX --> AI
    EX --> OCR
    EX --> CHAT
    EX --> SERIAL
    SERIAL --> ROBOT
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
    with urllib.request.urlopen(req) as response, open('backend_architecture.png', 'wb') as out_file:
        data = response.read()
        out_file.write(data)
    print("Image saved successfully.")
except Exception as e:
    print(f"Error: {e}")
