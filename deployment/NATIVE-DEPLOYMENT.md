# ClovaLink Non-Docker Deployment Guide

This guide covers deploying ClovaLink directly on a host without Docker. This approach provides:

- **Direct system integration** - ClovaLink runs as native systemd services
- **Better performance** - No container overhead
- **Simpler debugging** - Direct access to logs and processes
- **Flexibility** - Full control over each component

## Quick Start

### One-Line Installation

```bash
curl -fsSL https://raw.githubusercontent.com/ClovaLink/ClovaLink/main/deployment/install-native.sh | sudo bash
```

This automated installer will:
- Install all system dependencies (PostgreSQL, Redis, Nginx)
- Install Rust and Node.js
- Build ClovaLink from source
- Configure systemd services
- Set up secure defaults
- Start all services

### Supported Operating Systems

- ✅ Ubuntu 20.04 LTS or later
- ✅ Ubuntu 22.04 LTS (recommended)
- ✅ Debian 11 or later

Other Linux distributions may work but are not officially supported.

## Manual Installation

### Prerequisites

#### System Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 1 core | 2+ cores |
| RAM | 2 GB | 4 GB |
| Storage | 10 GB | 20+ GB |
| OS | Ubuntu 20.04+ | Ubuntu 22.04 LTS |

#### Required Software

- PostgreSQL 14+
- Redis 6+
- Nginx
- Rust 1.75+
- Node.js 20+
- Build tools (gcc, pkg-config, libssl-dev)

### Step 1: Install Dependencies

#### Ubuntu/Debian

```bash
# Update package list
sudo apt-get update

# Install system dependencies
sudo apt-get install -y \
    curl wget gnupg2 software-properties-common \
    build-essential pkg-config libssl-dev ca-certificates \
    postgresql postgresql-contrib redis-server nginx

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source $HOME/.cargo/env

# Install Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
sudo apt-get install -y nodejs
```

### Step 2: Create System User

```bash
# Create dedicated user for ClovaLink
sudo useradd -r -s /bin/bash -d /opt/clovalink -m clovalink

# Create required directories
sudo mkdir -p /opt/clovalink/{backend,frontend,logs}
sudo mkdir -p /var/log/clovalink

# Set permissions
sudo chown -R clovalink:clovalink /opt/clovalink
sudo chown -R clovalink:clovalink /var/log/clovalink
```

### Step 3: Setup PostgreSQL

```bash
# Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user
sudo -u postgres psql << EOF
CREATE DATABASE clovalink;
CREATE USER clovalink WITH PASSWORD 'your-secure-password-here';
GRANT ALL PRIVILEGES ON DATABASE clovalink TO clovalink;
ALTER DATABASE clovalink OWNER TO clovalink;
EOF
```

### Step 4: Setup Redis

```bash
# Start Redis
sudo systemctl start redis-server
sudo systemctl enable redis-server

# Verify Redis is running
redis-cli ping  # Should return PONG
```

### Step 5: Build ClovaLink

#### Backend

```bash
# Clone repository
cd /tmp
git clone https://github.com/ClovaLink/ClovaLink.git
cd ClovaLink/backend

# Build backend
export SQLX_OFFLINE=true
cargo build --release --bin clovalink_api

# Copy binary to installation directory
sudo cp target/release/clovalink_api /opt/clovalink/backend/clovalink_backend
sudo cp -r migrations /opt/clovalink/backend/

# Set permissions
sudo chown -R clovalink:clovalink /opt/clovalink/backend
```

#### Frontend

```bash
# Build frontend
cd /tmp/ClovaLink/frontend
npm install
npm run build

# Copy build to installation directory
sudo cp -r dist /opt/clovalink/frontend/

# Set permissions
sudo chown -R clovalink:clovalink /opt/clovalink/frontend
```

### Step 6: Configure Environment

Create `/opt/clovalink/backend/.env`:

```bash
sudo tee /opt/clovalink/backend/.env > /dev/null << 'EOF'
# Security
JWT_SECRET=your-64-character-random-string-here

# Database
DATABASE_URL=postgres://clovalink:your-secure-password@localhost:5432/clovalink

# Redis
REDIS_URL=redis://localhost:6379

# Storage
STORAGE_TYPE=local
UPLOAD_DIR=/opt/clovalink/backend/uploads

# Encryption (generate with: openssl rand -base64 32)
ENCRYPTION_KEY=your-base64-encoded-32-byte-key

# Environment
ENVIRONMENT=production
RUST_LOG=info

# Server
HOST=127.0.0.1
PORT=3000

# Base URL
BASE_URL=http://your-domain.com:8080
CORS_ALLOWED_ORIGINS=http://your-domain.com:8080
EOF

# Secure the file
sudo chmod 600 /opt/clovalink/backend/.env
sudo chown clovalink:clovalink /opt/clovalink/backend/.env
```

**Generate secure secrets:**

```bash
# JWT Secret (64 characters)
openssl rand -base64 48 | tr -d '/+=' | head -c 64

# Encryption Key (32 bytes, base64 encoded)
openssl rand -base64 32
```

### Step 7: Validate Configuration

```bash
# Download and run validation script
curl -fsSL https://raw.githubusercontent.com/ClovaLink/ClovaLink/main/deployment/scripts/validate-env.sh | bash -s /opt/clovalink/backend/.env
```

### Step 8: Run Database Migrations

```bash
cd /opt/clovalink/backend

# Run each migration
for migration in migrations/*.sql; do
    PGPASSWORD=your-secure-password psql -h localhost -U clovalink -d clovalink -f "$migration"
done
```

### Step 9: Setup Systemd Services

#### Backend Service

Create `/etc/systemd/system/clovalink-backend.service`:

```bash
sudo tee /etc/systemd/system/clovalink-backend.service > /dev/null << 'EOF'
[Unit]
Description=ClovaLink Backend API Server
After=network.target postgresql.service redis.service
Wants=postgresql.service redis.service

[Service]
Type=simple
User=clovalink
Group=clovalink
WorkingDirectory=/opt/clovalink/backend
EnvironmentFile=/opt/clovalink/backend/.env
ExecStart=/opt/clovalink/backend/clovalink_backend
Restart=on-failure
RestartSec=5s

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/clovalink/backend/uploads
ReadWritePaths=/var/log/clovalink

# Resource limits
LimitNOFILE=65536
LimitNPROC=512

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=clovalink-backend

[Install]
WantedBy=multi-user.target
EOF
```

#### Frontend Service (Nginx)

Download nginx configuration:

```bash
sudo curl -fsSL https://raw.githubusercontent.com/ClovaLink/ClovaLink/main/deployment/nginx.conf \
    -o /opt/clovalink/frontend/nginx.conf
```

Create `/etc/systemd/system/clovalink-frontend.service`:

```bash
sudo tee /etc/systemd/system/clovalink-frontend.service > /dev/null << 'EOF'
[Unit]
Description=ClovaLink Frontend (Nginx)
After=network.target clovalink-backend.service
Wants=clovalink-backend.service

[Service]
Type=forking
PIDFile=/run/nginx-clovalink.pid
ExecStartPre=/usr/sbin/nginx -t -c /opt/clovalink/frontend/nginx.conf
ExecStart=/usr/sbin/nginx -c /opt/clovalink/frontend/nginx.conf
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
```

### Step 10: Start Services

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable services to start on boot
sudo systemctl enable clovalink-backend
sudo systemctl enable clovalink-frontend

# Start services
sudo systemctl start clovalink-backend
sudo systemctl start clovalink-frontend

# Check status
sudo systemctl status clovalink-backend
sudo systemctl status clovalink-frontend
```

## Post-Installation

### Access ClovaLink

- **Web Interface**: http://your-server:8080
- **API Endpoint**: http://your-server:3000

### Default Credentials

| Role | Email | Password |
|------|-------|----------|
| SuperAdmin | superadmin@clovalink.com | password123 |
| Admin | admin@clovalink.com | password123 |

**⚠️ Change these passwords immediately!**

### Verify Installation

```bash
# Check backend is responding
curl http://localhost:3000/health

# Check logs
sudo journalctl -u clovalink-backend -f
sudo journalctl -u clovalink-frontend -f
```

## Service Management

### Common Commands

```bash
# Restart services
sudo systemctl restart clovalink-backend
sudo systemctl restart clovalink-frontend

# Stop services
sudo systemctl stop clovalink-backend
sudo systemctl stop clovalink-frontend

# View logs
sudo journalctl -u clovalink-backend -f
sudo journalctl -u clovalink-frontend -f

# View recent logs
sudo journalctl -u clovalink-backend -n 100 --no-pager
```

### Updating ClovaLink

```bash
# Stop services
sudo systemctl stop clovalink-backend clovalink-frontend

# Backup configuration
sudo cp /opt/clovalink/backend/.env /opt/clovalink/backend/.env.backup

# Pull latest code
cd /tmp
git clone https://github.com/ClovaLink/ClovaLink.git
cd ClovaLink

# Build backend
cd backend
export SQLX_OFFLINE=true
cargo build --release --bin clovalink_api
sudo cp target/release/clovalink_api /opt/clovalink/backend/clovalink_backend

# Build frontend
cd ../frontend
npm install
npm run build
sudo rm -rf /opt/clovalink/frontend/dist
sudo cp -r dist /opt/clovalink/frontend/

# Run new migrations (if any)
cd /tmp/ClovaLink/backend
for migration in migrations/*.sql; do
    # Check if migration was already run
    migration_name=$(basename "$migration")
    PGPASSWORD=your-password psql -h localhost -U clovalink -d clovalink -f "$migration" 2>/dev/null || true
done

# Restart services
sudo systemctl start clovalink-backend clovalink-frontend
```

## Advanced Configuration

### HTTPS Setup with Let's Encrypt

```bash
# Install Certbot
sudo apt-get install -y certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d your-domain.com

# Certbot will automatically configure Nginx for HTTPS
```

### S3 Storage Configuration

Edit `/opt/clovalink/backend/.env`:

```bash
# S3 Configuration
STORAGE_TYPE=s3
S3_BUCKET=your-bucket-name
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_REGION=us-east-1
USE_PRESIGNED_URLS=true

# For Wasabi (S3-compatible)
S3_ENDPOINT=https://s3.wasabisys.com

# For MinIO (self-hosted)
S3_ENDPOINT=http://your-minio-server:9000
S3_PATH_STYLE=true
```

### ClamAV Virus Scanning

```bash
# Install ClamAV
sudo apt-get install -y clamav clamav-daemon

# Update virus definitions
sudo freshclam

# Start ClamAV daemon
sudo systemctl start clamav-daemon
sudo systemctl enable clamav-daemon

# Configure ClovaLink
# Add to /opt/clovalink/backend/.env:
CLAMAV_ENABLED=true
CLAMAV_HOST=localhost
CLAMAV_PORT=3310

# Restart backend
sudo systemctl restart clovalink-backend
```

### Email Notifications (SMTP)

Add to `/opt/clovalink/backend/.env`:

```bash
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password
SMTP_FROM=noreply@yourdomain.com
```

## Monitoring

### Setup Log Rotation

Create `/etc/logrotate.d/clovalink`:

```bash
sudo tee /etc/logrotate.d/clovalink > /dev/null << 'EOF'
/var/log/clovalink/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 clovalink clovalink
    sharedscripts
    postrotate
        systemctl reload clovalink-frontend > /dev/null 2>&1 || true
    endscript
}
EOF
```

### System Monitoring

```bash
# CPU and Memory usage
sudo systemctl status clovalink-backend
sudo systemctl status clovalink-frontend

# Detailed resource usage
top -u clovalink

# Disk usage
du -sh /opt/clovalink/backend/uploads
```

## Troubleshooting

### Backend won't start

```bash
# Check logs
sudo journalctl -u clovalink-backend -n 50 --no-pager

# Verify database connection
PGPASSWORD=your-password psql -h localhost -U clovalink -d clovalink -c "SELECT 1;"

# Verify Redis connection
redis-cli ping

# Check permissions
sudo ls -la /opt/clovalink/backend/
```

### Port already in use

```bash
# Check what's using port 3000
sudo lsof -i :3000

# Check what's using port 8080
sudo lsof -i :8080

# Change ports in nginx.conf and .env if needed
```

### High memory usage

```bash
# Check PostgreSQL connections
sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity;"

# Adjust connection pool in .env
DB_MAX_CONNECTIONS=25
DB_MIN_CONNECTIONS=5

sudo systemctl restart clovalink-backend
```

### Database migration errors

```bash
# Check which migrations have been run
PGPASSWORD=your-password psql -h localhost -U clovalink -d clovalink -c "\dt"

# Manually run a specific migration
PGPASSWORD=your-password psql -h localhost -U clovalink -d clovalink -f migrations/001_initial_schema.sql
```

## Security Hardening

### Firewall Configuration

```bash
# Allow SSH, HTTP, HTTPS
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Block direct access to backend (force through Nginx)
sudo ufw deny 3000/tcp

# Enable firewall
sudo ufw enable
```

### Regular Updates

```bash
# Update system packages
sudo apt-get update
sudo apt-get upgrade -y

# Update Rust
rustup update

# Update Node.js
sudo npm install -g npm@latest
```

## Backup and Recovery

### Database Backup

```bash
# Create backup
PGPASSWORD=your-password pg_dump -h localhost -U clovalink clovalink > clovalink-backup-$(date +%Y%m%d).sql

# Restore backup
PGPASSWORD=your-password psql -h localhost -U clovalink -d clovalink < clovalink-backup-20240101.sql
```

### Configuration Backup

```bash
# Backup configuration and uploads
sudo tar -czf clovalink-config-backup-$(date +%Y%m%d).tar.gz \
    /opt/clovalink/backend/.env \
    /opt/clovalink/backend/uploads \
    /opt/clovalink/frontend/nginx.conf
```

### Automated Backups

Create `/opt/clovalink/scripts/backup.sh`:

```bash
#!/bin/bash
BACKUP_DIR="/var/backups/clovalink"
mkdir -p $BACKUP_DIR

# Database backup
PGPASSWORD=your-password pg_dump -h localhost -U clovalink clovalink | gzip > \
    $BACKUP_DIR/db-$(date +%Y%m%d-%H%M%S).sql.gz

# Keep only last 7 days
find $BACKUP_DIR -name "db-*.sql.gz" -mtime +7 -delete
```

Add to crontab:

```bash
# Daily backup at 2 AM
0 2 * * * /opt/clovalink/scripts/backup.sh
```

## Comparison: Docker vs Native

| Feature | Docker | Native |
|---------|--------|--------|
| **Installation** | Easier (one command) | More steps |
| **Performance** | Good (container overhead) | Better (no overhead) |
| **Resource Usage** | Higher | Lower |
| **Isolation** | Excellent | Good (systemd) |
| **Updates** | Simple (pull image) | Requires rebuild |
| **Debugging** | Requires docker exec | Direct access |
| **Portability** | High | OS-dependent |
| **Custom Integration** | Limited | Full control |

## Support

- Documentation: https://github.com/ClovaLink/ClovaLink
- Issues: https://github.com/ClovaLink/ClovaLink/issues
- Hosted Version: https://clovalink.com
