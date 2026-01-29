# ClovaLink Quick Reference Guide

Quick command reference for both Docker and native deployments.

## Installation

### Docker
```bash
curl -fsSL https://raw.githubusercontent.com/ClovaLink/ClovaLink/main/install.sh | bash
```

### Native
```bash
curl -fsSL https://raw.githubusercontent.com/ClovaLink/ClovaLink/main/deployment/install-native.sh | sudo bash
```

## Service Management

### Start Services

**Docker:**
```bash
docker compose up -d
```

**Native:**
```bash
sudo systemctl start clovalink-backend
sudo systemctl start clovalink-frontend
```

### Stop Services

**Docker:**
```bash
docker compose down
```

**Native:**
```bash
sudo systemctl stop clovalink-backend
sudo systemctl stop clovalink-frontend
```

### Restart Services

**Docker:**
```bash
docker compose restart
# Or restart specific service
docker compose restart backend
```

**Native:**
```bash
sudo systemctl restart clovalink-backend
sudo systemctl restart clovalink-frontend
# Or restart both at once
sudo systemctl restart clovalink-backend clovalink-frontend
```

### Check Status

**Docker:**
```bash
docker compose ps
```

**Native:**
```bash
sudo systemctl status clovalink-backend
sudo systemctl status clovalink-frontend
```

## Logs

### View Logs

**Docker:**
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f backend
docker compose logs -f frontend

# Last 100 lines
docker compose logs --tail=100 backend
```

**Native:**
```bash
# Backend logs
sudo journalctl -u clovalink-backend -f

# Frontend logs
sudo journalctl -u clovalink-frontend -f

# Last 100 lines
sudo journalctl -u clovalink-backend -n 100

# Both services
sudo journalctl -u clovalink-backend -u clovalink-frontend -f
```

### Search Logs

**Docker:**
```bash
docker compose logs backend | grep "ERROR"
docker compose logs --since="1h" backend
```

**Native:**
```bash
sudo journalctl -u clovalink-backend | grep "ERROR"
sudo journalctl -u clovalink-backend --since="1 hour ago"
sudo journalctl -u clovalink-backend --since "2024-01-01 00:00:00"
```

## Configuration

### Edit Configuration

**Docker:**
```bash
# Edit .env file
nano .env
# Or
vim .env

# Apply changes
docker compose down
docker compose up -d
```

**Native:**
```bash
# Edit .env file
sudo nano /opt/clovalink/backend/.env
# Or
sudo vim /opt/clovalink/backend/.env

# Validate changes
bash deployment/scripts/validate-env.sh /opt/clovalink/backend/.env

# Apply changes
sudo systemctl restart clovalink-backend
```

### View Configuration

**Docker:**
```bash
cat .env
docker compose config
```

**Native:**
```bash
sudo cat /opt/clovalink/backend/.env
```

## Database Operations

### Access Database

**Docker:**
```bash
docker compose exec postgres psql -U postgres -d clovalink
```

**Native:**
```bash
sudo -u postgres psql -d clovalink
# Or with password
psql -h localhost -U clovalink -d clovalink
```

### Backup Database

**Docker:**
```bash
docker compose exec postgres pg_dump -U postgres clovalink > backup-$(date +%Y%m%d).sql
```

**Native:**
```bash
pg_dump -h localhost -U clovalink clovalink > backup-$(date +%Y%m%d).sql
```

### Restore Database

**Docker:**
```bash
docker compose exec -T postgres psql -U postgres clovalink < backup.sql
```

**Native:**
```bash
psql -h localhost -U clovalink -d clovalink < backup.sql
```

### Run Migrations

**Docker:**
```bash
# Migrations run automatically on startup
# To run manually:
docker compose exec backend /bin/sh -c 'for f in migrations/*.sql; do psql $DATABASE_URL -f $f; done'
```

**Native:**
```bash
cd /opt/clovalink/backend
for migration in migrations/*.sql; do
    psql -h localhost -U clovalink -d clovalink -f "$migration"
done
```

## Updates

### Update to Latest Version

**Docker:**
```bash
cd /path/to/clovalink
docker compose pull
docker compose up -d
```

**Native:**
```bash
# Stop services
sudo systemctl stop clovalink-backend clovalink-frontend

# Backup configuration
sudo cp /opt/clovalink/backend/.env /opt/clovalink/backend/.env.backup

# Download and build latest
cd /tmp
git clone https://github.com/ClovaLink/ClovaLink.git
cd ClovaLink/backend
export SQLX_OFFLINE=true
cargo build --release --bin clovalink_api
sudo cp target/release/clovalink_api /opt/clovalink/backend/clovalink_backend

cd ../frontend
npm install && npm run build
sudo rm -rf /opt/clovalink/frontend/dist
sudo cp -r dist /opt/clovalink/frontend/

# Restart services
sudo systemctl start clovalink-backend clovalink-frontend
```

### Rollback

**Docker:**
```bash
# Pull specific version
docker compose pull clovalink-backend:v1.2.3
docker compose up -d
```

**Native:**
```bash
# Restore from backup
sudo systemctl stop clovalink-backend
sudo cp /opt/clovalink/backend/clovalink_backend.backup /opt/clovalink/backend/clovalink_backend
sudo systemctl start clovalink-backend
```

## Troubleshooting

### Check Service Health

**Docker:**
```bash
# Health check
curl http://localhost:3000/health

# Container status
docker compose ps
docker inspect clovalink-backend
```

**Native:**
```bash
# Health check
curl http://localhost:3000/health

# Service status
sudo systemctl status clovalink-backend
sudo systemctl status clovalink-frontend

# Check if ports are listening
sudo lsof -i :3000  # Backend
sudo lsof -i :8080  # Frontend
```

### Check Resource Usage

**Docker:**
```bash
docker stats
docker compose exec backend top
```

**Native:**
```bash
# Overall system
htop
top -u clovalink

# Specific service
sudo systemctl status clovalink-backend | grep Memory
sudo systemctl status clovalink-backend | grep CPU
```

### View Errors

**Docker:**
```bash
docker compose logs backend | grep -i error
docker compose logs backend | grep -i warning
```

**Native:**
```bash
sudo journalctl -u clovalink-backend -p err
sudo journalctl -u clovalink-backend -p warning
sudo journalctl -u clovalink-backend --since today | grep -i error
```

### Restart Services on Boot

**Docker:**
```bash
# Already enabled by default with restart: unless-stopped
docker compose up -d
```

**Native:**
```bash
# Enable autostart
sudo systemctl enable clovalink-backend
sudo systemctl enable clovalink-frontend

# Disable autostart
sudo systemctl disable clovalink-backend
sudo systemctl disable clovalink-frontend
```

## File Management

### View Uploads Directory

**Docker:**
```bash
docker compose exec backend ls -lh /app/uploads
```

**Native:**
```bash
sudo ls -lh /opt/clovalink/backend/uploads
```

### Check Disk Usage

**Docker:**
```bash
# All volumes
docker system df

# Specific volume
docker compose exec backend du -sh /app/uploads
```

**Native:**
```bash
sudo du -sh /opt/clovalink/backend/uploads
df -h /opt/clovalink
```

### Backup Uploads

**Docker:**
```bash
docker compose exec backend tar -czf - /app/uploads > uploads-backup-$(date +%Y%m%d).tar.gz
```

**Native:**
```bash
sudo tar -czf uploads-backup-$(date +%Y%m%d).tar.gz /opt/clovalink/backend/uploads
```

## Network & Connectivity

### Test Backend API

**Both:**
```bash
# Health check
curl http://localhost:3000/health

# Login test
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"superadmin@clovalink.com","password":"password123"}'
```

### Check Open Ports

**Docker:**
```bash
docker compose ps
netstat -tulpn | grep docker
```

**Native:**
```bash
sudo netstat -tulpn | grep clovalink
sudo lsof -i :3000
sudo lsof -i :8080
```

### Check Database Connectivity

**Docker:**
```bash
docker compose exec backend sh -c 'psql $DATABASE_URL -c "SELECT 1;"'
```

**Native:**
```bash
psql -h localhost -U clovalink -d clovalink -c "SELECT 1;"
```

### Check Redis Connectivity

**Docker:**
```bash
docker compose exec redis redis-cli ping
```

**Native:**
```bash
redis-cli ping
```

## Security

### Change Permissions

**Docker:**
```bash
chmod 600 .env
```

**Native:**
```bash
sudo chmod 600 /opt/clovalink/backend/.env
sudo chown clovalink:clovalink /opt/clovalink/backend/.env
```

### View Active Sessions

**Both:**
```bash
# PostgreSQL connections
# Docker:
docker compose exec postgres psql -U postgres -c "SELECT * FROM pg_stat_activity;"

# Native:
sudo -u postgres psql -c "SELECT * FROM pg_stat_activity;"
```

### Generate New Secrets

**Both:**
```bash
# JWT Secret (64 characters)
openssl rand -base64 48 | tr -d '/+=' | head -c 64

# Encryption Key (32 bytes, base64)
openssl rand -base64 32

# Strong password
openssl rand -base64 24
```

## Performance Monitoring

### Monitor in Real-time

**Docker:**
```bash
# Resource usage
docker stats

# Network traffic
docker compose exec backend iftop
```

**Native:**
```bash
# Resource usage
htop -u clovalink

# Network traffic
sudo iftop -i eth0

# System load
uptime
```

### Check Performance Metrics

**Both:**
```bash
# API response time
time curl http://localhost:3000/health

# Database query time
# Docker:
docker compose exec postgres psql -U postgres -c "EXPLAIN ANALYZE SELECT * FROM files LIMIT 10;"

# Native:
sudo -u postgres psql -c "EXPLAIN ANALYZE SELECT * FROM files LIMIT 10;"
```

## Development

### Access Shell

**Docker:**
```bash
# Backend container
docker compose exec backend sh

# Database
docker compose exec postgres psql -U postgres -d clovalink
```

**Native:**
```bash
# Switch to clovalink user
sudo -u clovalink bash

# Database
psql -h localhost -U clovalink -d clovalink
```

### Run Tests

**Docker:**
```bash
docker compose exec backend cargo test
```

**Native:**
```bash
cd /opt/clovalink/backend
cargo test
```

### View Environment Variables

**Docker:**
```bash
docker compose exec backend env
```

**Native:**
```bash
sudo systemctl show clovalink-backend --property=Environment
```

## Quick Fixes

### Service won't start

**Docker:**
```bash
docker compose down
docker compose up -d
docker compose logs -f backend
```

**Native:**
```bash
sudo systemctl restart clovalink-backend
sudo journalctl -u clovalink-backend -n 50
```

### Port already in use

**Docker:**
```bash
# Change port in compose.yml
# From: "3000:3000"
# To:   "3001:3000"
docker compose up -d
```

**Native:**
```bash
# Check what's using the port
sudo lsof -i :3000

# Kill process or change port in .env
echo "PORT=3001" | sudo tee -a /opt/clovalink/backend/.env
sudo systemctl restart clovalink-backend
```

### Out of disk space

**Docker:**
```bash
# Clean up unused images and volumes
docker system prune -a
docker volume prune
```

**Native:**
```bash
# Find large files
sudo du -sh /opt/clovalink/* | sort -h
sudo find /opt/clovalink -type f -size +100M

# Clean old logs
sudo journalctl --vacuum-time=7d
```

## Getting Help

- Documentation: [deployment/NATIVE-DEPLOYMENT.md](NATIVE-DEPLOYMENT.md)
- Comparison: [deployment/DOCKER-VS-NATIVE.md](DOCKER-VS-NATIVE.md)
- Issues: https://github.com/ClovaLink/ClovaLink/issues
- Main README: [../README.md](../README.md)
