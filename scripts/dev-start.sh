#!/bin/bash
echo "🚀 Starting DarsakAI Dev Environment..."

docker-compose up -d

echo "⏳ Waiting for PostgreSQL..."
until docker-compose exec postgres pg_isready -U user 2>/dev/null; do
  sleep 1
done

cd backend
pip install -r requirements.txt
uvicorn src.main:app --reload --port 8000 &
BACKEND_PID=$!

echo "✅ Services running:"
echo "   - Backend: http://localhost:8000"
echo "   - API Docs: http://localhost:8000/docs"
echo "   - Health: http://localhost:8000/health"
echo ""
echo "🛑 To stop: kill $BACKEND_PID && docker-compose down"

wait $BACKEND_PID
