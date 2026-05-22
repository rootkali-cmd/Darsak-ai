# DarsakAI Deployment Guide

## Local Development

### Prerequisites
- Docker & Docker Compose
- Python 3.10+
- Node.js 18+ (for web portal)
- Flutter 3.19+ (for mobile/desktop)

### 1. Start Infrastructure
```bash
docker-compose up -d postgres redis
```

### 2. Start Backend
```bash
cd backend
pip install -r requirements.txt
uvicorn src.main:app --reload --port 8000
```

### 3. (Optional) Start Ollama for AI
```bash
docker-compose up -d ollama
docker exec darsak-ollama ollama pull qwen2.5:7b-instruct
```

## Production Deployment

### Docker Compose Production
```yaml
# docker-compose.prod.yml
services:
  backend:
    build: ./backend
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql+asyncpg://user:${DB_PASS}@postgres:5432/darsakdb
      - SECRET_KEY=${SECRET_KEY}
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_started
    restart: unless-stopped
```

### Environment Variables (Production)
```bash
# Generate secure keys
openssl rand -hex 32  # For SECRET_KEY
openssl rand -base64 32  # For database password

# .env production
DATABASE_URL=postgresql+asyncpg://user:<strong-password>@postgres:5432/darsakdb
SECRET_KEY=<64-char-hex-string>
CORS_ORIGINS=["https://yourdomain.com"]
LOG_LEVEL=WARNING
```

### Nginx Reverse Proxy
```nginx
server {
    listen 80;
    server_name api.yourdomain.com;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### SSL (Let's Encrypt)
```bash
sudo certbot --nginx -d api.yourdomain.com
```

### Database Backup Script
```bash
#!/bin/bash
# backup.sh
BACKUP_DIR="/backups/darsak"
mkdir -p $BACKUP_DIR
DATE=$(date +%Y%m%d_%H%M%S)
docker-compose exec postgres pg_dump -U user darsakdb > "$BACKUP_DIR/darsak_$DATE.sql"
# Keep last 7 days
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
```

### Cron (Daily Backup)
```bash
0 2 * * * /path/to/backup.sh
```
