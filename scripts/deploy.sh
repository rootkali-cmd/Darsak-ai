#!/bin/bash
set -e

echo "🚀 DarsakAI Deploy Script"
echo "========================"

# --- Pull latest code ---
if [ -d /opt/darsakai ]; then
  echo "📥 Pulling latest code..."
  cd /opt/darsakai
  git pull origin main
else
  echo "📥 Cloning repository..."
  git clone https://github.com/rootkali-cmd/Darsak-ai.git /opt/darsakai
  cd /opt/darsakai
fi

# --- Copy .env if not exists ---
if [ ! -f .env.production ]; then
  echo "⚠️  .env.production not found!"
  echo "📝 Copying from example..."
  cp .env.production.example .env.production
  echo "✏️  Edit .env.production with your secrets, then re-run this script."
  exit 1
fi

# --- Pull Ollama model ---
echo "🤖 Pulling Ollama model (first time only)..."
docker exec darsak-ollama ollama pull qwen2.5:7b-instruct 2>/dev/null || true

# --- Build & start ---
echo "🏗️  Building and starting containers..."
docker compose -f docker-compose.yml up -d --build

# --- Status ---
echo ""
echo "✅ DarsakAI deployed!"
echo "📡 Backend: http://$(curl -s ifconfig.me):8000"
echo "🌐 Web:     http://$(curl -s ifconfig.me):3000"
echo "📚 API Docs: http://$(curl -s ifconfig.me):8000/docs"
echo ""
echo "💡 To view logs: docker compose logs -f"
echo "💡 To stop:      docker compose down"
