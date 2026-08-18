#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# setup.sh — Bootstrap Ollama + Chatbot on a fresh EC2 instance
#
# Supports: Ubuntu 22.04/24.04 LTS  |  Amazon Linux 2023
#
# Usage:
#   chmod +x setup.sh
#   sudo ./setup.sh [--model <ollama-model>] [--port <chatbot-port>]
#
# Examples:
#   sudo ./setup.sh                         # no model pulled; opens port 8000
#   sudo ./setup.sh --model llama3.2        # pulls llama3.2 after startup
#   sudo ./setup.sh --model mistral --port 3000
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
OLLAMA_MODEL=""
API_PORT=8000
REPO_DIR="/opt/ollama-chatbot"

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --model)  OLLAMA_MODEL="$2"; shift 2 ;;
    --port)   API_PORT="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────
log()  { echo -e "\033[1;34m[setup]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[  ok ]\033[0m $*"; }
warn() { echo -e "\033[1;33m[ warn]\033[0m $*"; }

detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "$ID"
  else
    echo "unknown"
  fi
}

# ── 1. Install Docker ─────────────────────────────────────────────────────────
install_docker() {
  if command -v docker &>/dev/null; then
    ok "Docker already installed: $(docker --version)"
    return
  fi

  OS=$(detect_os)
  log "Installing Docker on $OS …"

  case $OS in
    ubuntu|debian)
      apt-get update -qq
      apt-get install -y -qq ca-certificates curl gnupg lsb-release
      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      chmod a+r /etc/apt/keyrings/docker.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/docker.list
      apt-get update -qq
      apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
      ;;
    amzn)
      dnf install -y docker
      systemctl enable --now docker
      # Docker Compose plugin
      COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest \
        | grep '"tag_name"' | cut -d'"' -f4)
      curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64" \
        -o /usr/local/lib/docker/cli-plugins/docker-compose
      chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
      ;;
    *)
      warn "Unsupported OS '$OS'. Install Docker manually then re-run."
      exit 1
      ;;
  esac

  systemctl enable --now docker
  ok "Docker installed."
}

# ── 2. Copy project files ─────────────────────────────────────────────────────
copy_project() {
  log "Copying project files to $REPO_DIR …"
  mkdir -p "$REPO_DIR"

  # If this script is run from the project directory, copy everything over
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [ "$SCRIPT_DIR" != "$REPO_DIR" ]; then
    cp -r "$SCRIPT_DIR"/. "$REPO_DIR/"
  fi

  ok "Files ready at $REPO_DIR"
}

# ── 3. Patch port in compose file if non-default ──────────────────────────────
patch_port() {
  if [ "$API_PORT" != "8000" ]; then
    log "Setting chatbot port to $API_PORT …"
    sed -i "s|\"8000:8000\"|\"${API_PORT}:8000\"|g" "$REPO_DIR/docker-compose.yml"
  fi
}

# ── 4. Start the stack ────────────────────────────────────────────────────────
start_stack() {
  log "Starting Docker Compose stack …"
  cd "$REPO_DIR"

  if [ -n "$OLLAMA_MODEL" ]; then
    export OLLAMA_MODEL
  fi

  # Tear down any previous run (removes containers, keeps volumes/models)
  docker compose down --remove-orphans 2>/dev/null || true

  docker compose up -d --build
  ok "Stack started."
}

# ── 5. Pull the model (if specified) ─────────────────────────────────────────
pull_model() {
  if [ -z "$OLLAMA_MODEL" ]; then
    warn "No model specified. Run this to pull one later:"
    warn "  docker exec ollama ollama pull <model-name>"
    warn "  e.g.: docker exec ollama ollama pull llama3.2"
    return
  fi

  log "Waiting for Ollama to be ready …"
  for i in $(seq 1 30); do
    if docker exec ollama ollama list &>/dev/null; then
      break
    fi
    sleep 2
  done

  log "Pulling model: $OLLAMA_MODEL (this may take a few minutes) …"
  docker exec ollama ollama pull "$OLLAMA_MODEL"
  ok "Model '$OLLAMA_MODEL' ready."
}

# ── 6. Print summary ──────────────────────────────────────────────────────────
print_summary() {
  PUBLIC_IP=$(curl -sf http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "<your-ec2-ip>")
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  ok "Setup complete!"
  echo ""
  echo "  LLM API     →  http://${PUBLIC_IP}:${API_PORT}"
  echo "  Ollama API  →  http://${PUBLIC_IP}:11434"
  echo ""
  echo "  Useful commands:"
  echo "    docker compose -f $REPO_DIR/docker-compose.yml logs -f"
  echo "    docker exec ollama ollama pull <model>"
  echo "    docker exec ollama ollama list"
  echo ""

  echo "  Test the API:"
  echo "    curl -X POST http://${PUBLIC_IP}:${API_PORT}/generate \\"
  echo "      -H \"Content-Type: application/json\" \\"
  echo "      -d '{\"prompt\":\"Hello\"}'"
  echo ""
  echo "  Local Test Client:"
  echo "    streamlit run streamlit_app.py"
  echo ""  
  echo "  AWS Security Group: make sure port ${API_PORT} is open for inbound TCP."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ── Main ──────────────────────────────────────────────────────────────────────
install_docker
copy_project
patch_port
start_stack
pull_model
print_summary