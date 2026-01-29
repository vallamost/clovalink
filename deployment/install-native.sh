#!/bin/bash
#
# ClovaLink Non-Docker Installer
# Installs ClovaLink directly on a host without Docker
#
# Usage: curl -fsSL https://raw.githubusercontent.com/ClovaLink/ClovaLink/main/deployment/install-native.sh | bash
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Print banner
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                                                               ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}   ${BOLD}🍀 ClovaLink Native Installer (No Docker)${NC}                  ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}   Enterprise File Management Made Simple                      ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                               ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root or with sudo${NC}"
    exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    echo -e "${RED}Cannot detect OS. This script supports Ubuntu/Debian.${NC}"
    exit 1
fi

echo -e "${BLUE}[1/10]${NC} Detected OS: ${BOLD}${PRETTY_NAME}${NC}"

# Function to generate random string
generate_secret() {
    if command -v openssl &> /dev/null; then
        openssl rand -base64 32 | tr -d '/+=' | head -c 32
    elif [ -f /dev/urandom ]; then
        cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 32
    else
        date +%s%N | sha256sum | head -c 32
    fi
}

# Function to check command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        return 1
    fi
    return 0
}

# Step 2: Install system dependencies
echo ""
echo -e "${BLUE}[2/10]${NC} Installing system dependencies..."

if [[ "$OS" == "ubuntu" ]] || [[ "$OS" == "debian" ]]; then
    apt-get update -qq
    apt-get install -y -qq curl wget gnupg2 software-properties-common \
        build-essential pkg-config libssl-dev ca-certificates \
        postgresql postgresql-contrib redis-server nginx \
        > /dev/null 2>&1
    echo -e "  ${GREEN}✓${NC} Installed PostgreSQL, Redis, Nginx, and build tools"
else
    echo -e "${RED}Unsupported OS. This script currently supports Ubuntu/Debian.${NC}"
    exit 1
fi

# Step 3: Install Rust (for building backend)
echo ""
echo -e "${BLUE}[3/10]${NC} Installing Rust..."

if ! check_command rustc; then
    export RUSTUP_HOME=/opt/rust
    export CARGO_HOME=/opt/rust
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path > /dev/null 2>&1
    source /opt/rust/env
    echo -e "  ${GREEN}✓${NC} Installed Rust $(rustc --version | cut -d' ' -f2)"
else
    echo -e "  ${GREEN}✓${NC} Rust already installed: $(rustc --version | cut -d' ' -f2)"
fi

# Step 4: Install Node.js (for building frontend)
echo ""
echo -e "${BLUE}[4/10]${NC} Installing Node.js..."

if ! check_command node; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - > /dev/null 2>&1
    apt-get install -y -qq nodejs > /dev/null 2>&1
    echo -e "  ${GREEN}✓${NC} Installed Node.js $(node --version)"
else
    echo -e "  ${GREEN}✓${NC} Node.js already installed: $(node --version)"
fi

# Step 5: Create clovalink user
echo ""
echo -e "${BLUE}[5/10]${NC} Creating clovalink user..."

if ! id -u clovalink > /dev/null 2>&1; then
    useradd -r -s /bin/bash -d /opt/clovalink -m clovalink
    echo -e "  ${GREEN}✓${NC} Created clovalink user"
else
    echo -e "  ${GREEN}✓${NC} User clovalink already exists"
fi

# Step 6: Setup PostgreSQL
echo ""
echo -e "${BLUE}[6/10]${NC} Setting up PostgreSQL..."

# Start PostgreSQL service
systemctl start postgresql
systemctl enable postgresql > /dev/null 2>&1

# Generate PostgreSQL password
POSTGRES_PASSWORD=$(generate_secret)

# Create database and user
sudo -u postgres psql -c "CREATE DATABASE clovalink;" 2>/dev/null || echo -e "  ${YELLOW}Database already exists${NC}"
sudo -u postgres psql -c "CREATE USER clovalink WITH PASSWORD '${POSTGRES_PASSWORD}';" 2>/dev/null || echo -e "  ${YELLOW}User already exists${NC}"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE clovalink TO clovalink;" > /dev/null 2>&1
sudo -u postgres psql -c "ALTER DATABASE clovalink OWNER TO clovalink;" > /dev/null 2>&1

echo -e "  ${GREEN}✓${NC} PostgreSQL configured"

# Step 7: Setup Redis
echo ""
echo -e "${BLUE}[7/10]${NC} Setting up Redis..."

systemctl start redis-server
systemctl enable redis-server > /dev/null 2>&1

echo -e "  ${GREEN}✓${NC} Redis configured"

# Step 8: Download and build ClovaLink
echo ""
echo -e "${BLUE}[8/10]${NC} Downloading and building ClovaLink..."

INSTALL_DIR="/opt/clovalink"
cd /tmp

# Clone repository
if [ ! -d "$INSTALL_DIR/backend" ]; then
    echo -e "  ${YELLOW}Cloning ClovaLink repository...${NC}"
    git clone https://github.com/ClovaLink/ClovaLink.git /tmp/clovalink-build > /dev/null 2>&1
    
    # Create directory structure
    mkdir -p $INSTALL_DIR/{backend,frontend,logs}
    
    # Build backend
    echo -e "  ${YELLOW}Building backend (this may take several minutes)...${NC}"
    cd /tmp/clovalink-build/backend
    source /opt/rust/env
    export SQLX_OFFLINE=true
    cargo build --release --bin clovalink_api > /dev/null 2>&1
    cp target/release/clovalink_api $INSTALL_DIR/backend/clovalink_backend
    cp -r migrations $INSTALL_DIR/backend/
    
    # Build frontend
    echo -e "  ${YELLOW}Building frontend...${NC}"
    cd /tmp/clovalink-build/frontend
    npm install > /dev/null 2>&1
    npm run build > /dev/null 2>&1
    cp -r dist $INSTALL_DIR/frontend/
    
    # Cleanup
    rm -rf /tmp/clovalink-build
    
    echo -e "  ${GREEN}✓${NC} Built and installed ClovaLink"
else
    echo -e "  ${GREEN}✓${NC} ClovaLink already installed"
fi

# Step 9: Configure ClovaLink
echo ""
echo -e "${BLUE}[9/10]${NC} Configuring ClovaLink..."

# Generate secrets
JWT_SECRET=$(generate_secret)
ENCRYPTION_KEY=$(openssl rand -base64 32)

# Create .env file
cat > $INSTALL_DIR/backend/.env << EOF
# ClovaLink Configuration
# Generated by native installer on $(date)

# Security - These were auto-generated, keep them secret!
JWT_SECRET=${JWT_SECRET}

# Database
DATABASE_URL=postgres://clovalink:${POSTGRES_PASSWORD}@localhost:5432/clovalink

# Redis
REDIS_URL=redis://localhost:6379

# Storage (local by default)
STORAGE_TYPE=local
UPLOAD_DIR=/opt/clovalink/backend/uploads

# Local Storage Encryption (ChaCha20-Poly1305)
ENCRYPTION_KEY=${ENCRYPTION_KEY}

# Environment
ENVIRONMENT=production
RUST_LOG=info

# Base URL for share links and notifications
BASE_URL=http://localhost:8080

# CORS
CORS_ALLOWED_ORIGINS=http://localhost:8080

# Server settings
HOST=127.0.0.1
PORT=3000
EOF

# Create uploads directory
mkdir -p $INSTALL_DIR/backend/uploads
mkdir -p /var/log/clovalink

# Set permissions
chown -R clovalink:clovalink $INSTALL_DIR
chown -R clovalink:clovalink /var/log/clovalink
chmod 600 $INSTALL_DIR/backend/.env

echo -e "  ${GREEN}✓${NC} Configuration created"
echo -e "  ${YELLOW}Note: JWT Secret and Encryption Key saved in $INSTALL_DIR/backend/.env${NC}"

# Run migrations
echo -e "  ${YELLOW}Running database migrations...${NC}"
cd $INSTALL_DIR/backend
for migration in migrations/*.sql; do
    PGPASSWORD=${POSTGRES_PASSWORD} psql -h localhost -U clovalink -d clovalink -f $migration > /dev/null 2>&1 || true
done
echo -e "  ${GREEN}✓${NC} Database migrations completed"

# Step 10: Setup systemd services
echo ""
echo -e "${BLUE}[10/10]${NC} Setting up systemd services..."

# Create deployment directory and copy scripts
mkdir -p $INSTALL_DIR/deployment/scripts
curl -fsSL https://raw.githubusercontent.com/ClovaLink/ClovaLink/main/deployment/scripts/start-backend.sh -o $INSTALL_DIR/deployment/scripts/start-backend.sh
chmod +x $INSTALL_DIR/deployment/scripts/start-backend.sh

# Download and install systemd service files
curl -fsSL https://raw.githubusercontent.com/ClovaLink/ClovaLink/main/deployment/systemd/clovalink-backend.service -o /etc/systemd/system/clovalink-backend.service
curl -fsSL https://raw.githubusercontent.com/ClovaLink/ClovaLink/main/deployment/nginx.conf -o $INSTALL_DIR/frontend/nginx.conf
curl -fsSL https://raw.githubusercontent.com/ClovaLink/ClovaLink/main/deployment/systemd/clovalink-frontend.service -o /etc/systemd/system/clovalink-frontend.service

# Reload systemd
systemctl daemon-reload

# Enable and start services
systemctl enable clovalink-backend > /dev/null 2>&1
systemctl start clovalink-backend

systemctl enable clovalink-frontend > /dev/null 2>&1
systemctl start clovalink-frontend

echo -e "  ${GREEN}✓${NC} Systemd services configured and started"

# Wait for services to be ready
echo ""
echo -e "  Waiting for services to start..."
sleep 5

# Check if services are running
BACKEND_STATUS=$(systemctl is-active clovalink-backend)
FRONTEND_STATUS=$(systemctl is-active clovalink-frontend)

if [[ "$BACKEND_STATUS" == "active" ]] && [[ "$FRONTEND_STATUS" == "active" ]]; then
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}                                                               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}   ${BOLD}🎉 ClovaLink is now running!${NC}                                ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                               ${GREEN}║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${BOLD}Web Interface:${NC}  ${CYAN}http://localhost:8080${NC}"
    echo -e "  ${BOLD}API Endpoint:${NC}   ${CYAN}http://localhost:3000${NC}"
    echo ""
    echo -e "  ${BOLD}Default Login:${NC}"
    echo -e "    Email:    ${CYAN}superadmin@clovalink.com${NC}"
    echo -e "    Password: ${CYAN}password123${NC}"
    echo ""
    echo -e "  ${YELLOW}⚠️  Change the default password immediately!${NC}"
    echo ""
    echo -e "  ${BOLD}Useful Commands:${NC}"
    echo -e "    View backend logs:  ${CYAN}journalctl -u clovalink-backend -f${NC}"
    echo -e "    View frontend logs: ${CYAN}journalctl -u clovalink-frontend -f${NC}"
    echo -e "    Restart backend:    ${CYAN}systemctl restart clovalink-backend${NC}"
    echo -e "    Restart frontend:   ${CYAN}systemctl restart clovalink-frontend${NC}"
    echo -e "    Stop all:           ${CYAN}systemctl stop clovalink-backend clovalink-frontend${NC}"
    echo ""
    echo -e "  ${BOLD}Configuration:${NC}"
    echo -e "    Backend config:     ${CYAN}$INSTALL_DIR/backend/.env${NC}"
    echo -e "    Frontend config:    ${CYAN}$INSTALL_DIR/frontend/nginx.conf${NC}"
    echo ""
else
    echo ""
    echo -e "${RED}Something went wrong. Check the logs:${NC}"
    echo -e "  Backend:  systemctl status clovalink-backend"
    echo -e "  Frontend: systemctl status clovalink-frontend"
    echo -e "  Backend logs: journalctl -u clovalink-backend -n 50"
    echo -e "  Frontend logs: journalctl -u clovalink-frontend -n 50"
    exit 1
fi
