# 🚀 Self-Hosted LLM Deployment on AWS EC2 using Ollama, FastAPI, Docker & Streamlit

A complete end-to-end project for deploying a self-hosted Large Language Model (LLM) on an AWS EC2 instance using **Ollama + llama3.2**, exposing it through a **FastAPI REST API**, containerizing the application with **Docker/Docker Compose**, and testing it from a **Streamlit client**.

This project demonstrates a practical AI Engineer deployment workflow:

```text
Streamlit UI
     │
     │ HTTP
     ▼
AWS EC2 / Elastic IP
     │
     ▼
FastAPI :8000
     │
     │ Docker network
     ▼
Ollama :11434
     │
     ▼
llama3.2
```

---

## 📌 Project Objective

The goal of this project is to learn and implement a complete self-hosted LLM deployment pipeline:

- Run Ollama on AWS EC2
- Download and serve `llama3.2`
- Build a FastAPI wrapper around Ollama
- Containerize FastAPI using Docker
- Orchestrate Ollama + FastAPI using Docker Compose
- Expose the FastAPI API through EC2
- Assign an AWS Elastic IP for a stable public endpoint
- Build a Streamlit client
- Connect Streamlit to the AWS-hosted LLM API
- Test the complete end-to-end inference flow

---

# 🏗️ Final Architecture

```text
                         INTERNET
                            │
                            ▼
                 ┌─────────────────────┐
                 │   Streamlit Client  │
                 │   Local Windows PC  │
                 │       :8501         │
                 └──────────┬──────────┘
                            │
                            │ HTTP :8000
                            ▼
                 ┌─────────────────────┐
                 │      AWS EC2        │
                 │     Elastic IP      │
                 │                     │
                 │  ┌───────────────┐  │
                 │  │    FastAPI    │  │
                 │  │   ollama-api  │  │
                 │  │     :8000     │  │
                 │  └───────┬───────┘  │
                 │          │           │
                 │          │ Docker    │
                 │          │ Network   │
                 │          ▼           │
                 │  ┌───────────────┐  │
                 │  │    Ollama     │  │
                 │  │    :11434     │  │
                 │  │               │  │
                 │  │   llama3.2    │  │
                 │  └───────────────┘  │
                 └─────────────────────┘
```

---

# 🧰 Technology Stack

| Technology | Purpose |
|---|---|
| AWS EC2 | Cloud compute |
| Elastic IP | Stable public IPv4 address |
| Ubuntu | EC2 operating system |
| Docker | Containerization |
| Docker Compose | Multi-container orchestration |
| Ollama | Local/self-hosted LLM runtime |
| llama3.2 | LLM |
| FastAPI | REST API layer |
| Uvicorn | ASGI server |
| Pydantic | Request validation |
| HTTPX | FastAPI → Ollama communication |
| Streamlit | User interface / client |
| Python | Application language |
| Git | Version control |
| GitHub | Source code repository |

---

# 📁 Project Structure

```text
ollama-aws-deployment/
│
├── .gitignore
├── README.md
├── Dockerfile
├── docker-compose.yaml
├── app.py
├── main.py
├── pyproject.toml
├── requirement.txt
├── setup.sh
├── template.py
│
├── Dockerfile.streamlit
├── streamlit_app.py
└── requirements-streamlit.txt
```

The exact Streamlit files can be kept locally or committed if you want the complete client included in the repository.

---

# ☁️ Phase 1 — AWS EC2 Setup

Launch an EC2 instance with Ubuntu.

Recommended considerations:

- Choose an instance with enough RAM/CPU for the selected model.
- Configure SSH access using your key pair.
- Keep the EC2 security group restrictive.
- Allow SSH (`22`) from your own IP.
- Allow API port `8000` only when required for external testing.
- If Streamlit is also hosted on EC2 later, allow `8501` as required.

Connect:

```bash
ssh -i key_rsa.pem ubuntu@<EC2_PUBLIC_IP>
```

---

# 📌 Phase 2 — Clone the GitHub Repository

On EC2:

```bash
git clone <YOUR_GITHUB_REPOSITORY_URL>
cd ollama-aws-deployment
```

Verify:

```bash
ls -la
```

---

# 🐳 Phase 3 — Docker Compose

The final Compose architecture contains two backend services:

1. `ollama`
2. `api`

Example:

```yaml
services:

  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    restart: unless-stopped

    ports:
      - "11434:11434"

    volumes:
      - ollama_data:/root/.ollama

    healthcheck:
      test: ["CMD-SHELL", "ollama list >/dev/null 2>&1 || exit 1"]
      interval: 15s
      timeout: 10s
      retries: 8
      start_period: 30s

  api:
    build: .
    container_name: ollama-api
    restart: unless-stopped

    ports:
      - "8000:8000"

    environment:
      OLLAMA_BASE_URL: "http://ollama:11434"
      OLLAMA_MODEL: "${OLLAMA_MODEL:-llama3.2}"

    depends_on:
      ollama:
        condition: service_healthy

volumes:
  ollama_data:
```

### Important Docker networking concept

Inside Docker Compose:

```text
http://ollama:11434
```

is correct.

Do not use:

```text
http://localhost:11434
```

inside the FastAPI container.

`ollama` is the Docker Compose service name and Docker provides internal DNS for it.

---

# 🐍 Phase 4 — FastAPI Application

`app.py` provides three main endpoints:

```text
GET  /
GET  /health
GET  /models
POST /generate
```

The API acts as a wrapper around Ollama.

Request flow:

```text
Client
  │
  ▼
FastAPI
  │
  ▼
Ollama /api/generate
  │
  ▼
llama3.2
  │
  ▼
FastAPI
  │
  ▼
Client
```

Example request:

```bash
curl -X POST http://localhost:8000/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Explain Docker in one sentence"}'
```

Example response:

```json
{
  "model": "llama3.2",
  "response": "Docker is a containerization platform...",
  "done": true
}
```

---

# 🐳 Phase 5 — Dockerfile

The API container uses Python 3.12:

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY requirement.txt .

RUN pip install --no-cache-dir -r requirement.txt

COPY app.py .

EXPOSE 8000

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
```

Important Dockerfile syntax:

```dockerfile
COPY requirement.txt .
```

and:

```dockerfile
COPY app.py .
```

A previous version contained incomplete `COPY` statements and lowercase `copy`. The final Dockerfile above is the corrected version.

---

# 📦 Phase 6 — Python Dependencies

Example `requirement.txt`:

```text
fastapi==0.115.5
httpx==0.27.2
pydantic==2.10.3
uvicorn[standard]==0.32.1
```

---

# ▶️ Phase 7 — Build and Start the Deployment

From the project directory:

```bash
docker compose config
```

This should complete without YAML errors.

Build:

```bash
docker compose build --no-cache
```

Start:

```bash
docker compose up -d
```

Check:

```bash
docker compose ps
```

Logs:

```bash
docker compose logs -f
```

API logs:

```bash
docker compose logs -f api
```

Ollama logs:

```bash
docker compose logs -f ollama
```

---

# 🤖 Phase 8 — Download the Model

Check Ollama:

```bash
docker exec -it ollama ollama list
```

If `llama3.2` is not present:

```bash
docker exec -it ollama ollama pull llama3.2
```

Then:

```bash
docker exec -it ollama ollama list
```

The Docker volume:

```yaml
ollama_data:/root/.ollama
```

keeps the model data persistent across container recreation.

---

# 🩺 Phase 9 — Health Check

Test:

```bash
curl http://localhost:8000/health
```

Expected behavior:

```json
{
  "status": "healthy"
}
```

Also test:

```bash
curl http://localhost:8000/models
```

---

# 🧪 Phase 10 — Test Generation

```bash
curl -X POST http://localhost:8000/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Explain Docker in one sentence"}'
```

A successful response confirms:

```text
FastAPI → Ollama → llama3.2 → FastAPI
```

---

# 🌐 Phase 11 — Elastic IP

An EC2 public IPv4 address can change after stopping/starting an instance.

To provide a stable endpoint:

1. Allocate an Elastic IP in AWS.
2. Associate it with the existing EC2 instance.
3. Use the Elastic IP for external clients.

Example:

```text
Elastic IP:
15.xx.xx.xx
```

The Streamlit client can then use:

```python
API_URL = "http://15.xx.xx.xx:8000"
```

### Important

Do not use the EC2 private IP such as:

```text
172.31.x.x
```

for a client running outside the AWS VPC.

Do not expose Ollama port `11434` publicly just to make Streamlit work. The intended path is:

```text
Streamlit → FastAPI :8000 → Ollama :11434
```

---

# 🔐 AWS Security Group

For temporary testing:

```text
Inbound:

SSH       TCP 22     My IP
FastAPI   TCP 8000   My IP
```

Avoid:

```text
TCP 11434  0.0.0.0/0
```

For production, use stronger controls such as HTTPS, authentication, a reverse proxy/load balancer, and restricted network access.

---

# 🎨 Phase 12 — Streamlit Client

The Streamlit application is a separate client.

Example:

```python
import os
import requests
import streamlit as st

API_URL = os.getenv(
    "API_URL",
    "http://YOUR_ELASTIC_IP:8000"
)
```

The UI:

- Checks `/health`
- Loads `/models`
- Allows model selection
- Accepts a prompt
- Calls `/generate`
- Displays the generated response

Run locally:

```powershell
python -m venv .venv
.venv\Scripts\activate
python -m pip install --upgrade pip
python -m pip install streamlit requests
streamlit run streamlit_app.py
```

Open:

```text
http://localhost:8501
```

---

# 🧪 Phase 13 — End-to-End Test

The final test was successful.

The Streamlit application displayed:

```text
Connected to the deployed LLM API
```

and successfully returned an LLM response.

Therefore the complete path was verified:

```text
Windows
   │
   ▼
Streamlit
   │
   │ HTTP :8000
   ▼
AWS Elastic IP
   │
   ▼
EC2
   │
   ▼
FastAPI
   │
   │ http://ollama:11434
   ▼
Ollama
   │
   ▼
llama3.2
   │
   ▼
Generated Response
   │
   ▼
Streamlit
```

---

# 🛠️ Troubleshooting Guide

## Error 1 — No Compose file

Error:

```text
no configuration file provided: not found
```

Cause:

The command was executed from:

```text
/home/ubuntu
```

instead of the project directory.

Solution:

```bash
cd ~/ollama-aws-deployment
docker compose up -d --build
```

---

## Error 2 — `services.api.build must be a string`

Error:

```text
services.api.build must be a string
```

Cause:

Incorrect YAML structure/indentation under `build`.

Correct:

```yaml
api:
  build: .
```

or:

```yaml
api:
  build:
    context: .
```

---

## Error 3 — YAML scanner error

Error:

```text
could not find expected ':'
```

Cause:

The `docker-compose.yaml` contained accidental characters after the `volumes` section:

```text
^O
x
O
```

Solution:

Replace the file with a clean valid YAML configuration and verify:

```bash
docker compose config
```

---

## Error 4 — Incorrect Ollama port

A previous configuration contained:

```text
http://ollama:1134
```

The correct Ollama API port is:

```text
http://ollama:11434
```

Correct:

```yaml
OLLAMA_BASE_URL: "http://ollama:11434"
```

---

## Error 5 — Duplicate Dockerfiles

The project temporarily contained:

```text
Dockerfile
dockerfile
```

Linux treats filenames with different capitalization as different files.

The working API Dockerfile is:

```text
Dockerfile
```

The Streamlit Dockerfile, if containerizing Streamlit later, is intentionally:

```text
Dockerfile.streamlit
```

Avoid unnecessary duplicate Dockerfiles.

---

## Error 6 — Streamlit import error

Error:

```text
ImportError:
cannot import name 'DEFAULT_EXCLUDED_CONTENT_TYPES'
from 'starlette.middleware.gzip'
```

The local Streamlit virtual environment had a dependency/runtime problem.

Additional symptoms included:

```text
python -m pip
No module named pip
```

The clean solution was to recreate the local Streamlit virtual environment:

```powershell
deactivate
Remove-Item -Recurse -Force .venv

py -3.10 -m venv .venv
.venv\Scripts\activate

python -m pip install --upgrade pip
python -m pip install streamlit requests

python -m pip check
```

Then verify:

```powershell
python -c "import streamlit; print(streamlit.__version__)"
```

---

# 🧠 Key Lessons Learned

## 1. Docker Compose service names are DNS names

Inside Compose:

```text
api → ollama
```

uses:

```text
http://ollama:11434
```

not:

```text
localhost
```

---

## 2. `localhost` depends on where the request originates

From EC2 host:

```text
localhost:8000
```

means the EC2 host.

From the API container:

```text
localhost:8000
```

means the API container itself.

From Streamlit container:

```text
api:8000
```

means the FastAPI container.

---

## 3. Public IP and private IP are different

Example:

```text
Elastic/Public IP:
15.x.x.x

Private IP:
172.31.x.x
```

An external client uses the public/Elastic IP.

Docker services use internal service names.

---

## 4. Keep LLM runtime separate from API

Ollama:

```text
LLM inference
```

FastAPI:

```text
API/business layer
```

Streamlit:

```text
UI/client
```

This separation makes the system easier to debug, replace, and scale.

---

# 🚨 Security Notes

This project is a learning/deployment project.

For production:

- Do not expose Ollama directly to the internet.
- Add HTTPS.
- Add API authentication/authorization.
- Put FastAPI behind a reverse proxy or load balancer.
- Restrict Security Group rules.
- Avoid hard-coded secrets.
- Use environment variables or AWS Secrets Manager.
- Add rate limiting.
- Add logging and monitoring.
- Consider a domain name.
- Consider TLS certificates.
- Consider GPU-enabled EC2 for faster inference.
- Pin production dependencies.
- Avoid using `latest` images in production without a versioning strategy.

---

# 🔄 Useful Commands Cheat Sheet

### SSH

```bash
ssh -i key_rsa.pem ubuntu@<ELASTIC_IP>
```

### Project

```bash
cd ~/ollama-aws-deployment
```

### Validate Compose

```bash
docker compose config
```

### Build

```bash
docker compose build --no-cache
```

### Start

```bash
docker compose up -d
```

### Stop

```bash
docker compose down
```

### Status

```bash
docker compose ps
```

### Logs

```bash
docker compose logs -f
```

### API logs

```bash
docker compose logs -f api
```

### Ollama logs

```bash
docker compose logs -f ollama
```

### List models

```bash
docker exec -it ollama ollama list
```

### Pull model

```bash
docker exec -it ollama ollama pull llama3.2
```

### API health

```bash
curl http://localhost:8000/health
```

### API models

```bash
curl http://localhost:8000/models
```

### Generate

```bash
curl -X POST http://localhost:8000/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Explain Docker in one sentence"}'
```

---

# 📈 Future Improvements

Possible next stages:

```text
Stage 1
Current deployment
       ↓
Stage 2
Streamlit inside Docker
       ↓
Stage 3
HTTPS + Domain
       ↓
Stage 4
API Authentication
       ↓
Stage 5
Nginx / Reverse Proxy
       ↓
Stage 6
GPU-enabled EC2
       ↓
Stage 7
Monitoring + Logging
       ↓
Stage 8
RAG
       ↓
Stage 9
Vector Database
       ↓
Stage 10
Agentic AI
       ↓
Stage 11
CI/CD with GitHub Actions
```

---

# 👨‍💻 Author

**Shreeshail Mali**

AI Engineering / Data Engineering learning project.

Focus areas:

- Python
- FastAPI
- Docker
- AWS
- Ollama
- LLM deployment
- Streamlit
- AI Engineering

---

# ⭐ Project Outcome

This project successfully demonstrates:

> **Deploying a self-hosted LLM on AWS EC2 using Ollama, exposing it through FastAPI and Docker, and consuming it through an external Streamlit application.**

End-to-end inference was successfully tested.

