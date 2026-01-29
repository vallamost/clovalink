#!/bin/bash
#
# ClovaLink Backend Startup Script
# Works in both Docker and native environments
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Starting ClovaLink Backend...${NC}"

# Function to check if a service is reachable
wait_for_service() {
    local host=$1
    local port=$2
    local service=$3
    local max_attempts=30
    local attempt=1

    echo -e "${YELLOW}Waiting for $service at $host:$port...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        if nc -z $host $port 2>/dev/null || timeout 1 bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
            echo -e "${GREEN}✓ $service is ready${NC}"
            return 0
        fi
        echo -e "  Attempt $attempt/$max_attempts..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo -e "${RED}✗ Failed to connect to $service${NC}"
    return 1
}

# Validate required environment variables
echo -e "${BLUE}Validating environment variables...${NC}"

required_vars=(
    "DATABASE_URL"
    "REDIS_URL"
    "JWT_SECRET"
)

missing_vars=()
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -ne 0 ]; then
    echo -e "${RED}Error: Missing required environment variables:${NC}"
    for var in "${missing_vars[@]}"; do
        echo -e "  - $var"
    done
    exit 1
fi

echo -e "${GREEN}✓ All required environment variables are set${NC}"

# Extract database host and port from DATABASE_URL
DB_HOST=$(echo $DATABASE_URL | sed -n 's/.*@\([^:]*\):.*/\1/p')
DB_PORT=$(echo $DATABASE_URL | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')

# Extract Redis host and port from REDIS_URL
REDIS_HOST=$(echo $REDIS_URL | sed -n 's/.*:\/\/\([^:]*\):.*/\1/p')
if [ -z "$REDIS_HOST" ]; then
    # Try simpler pattern for redis://hostname
    REDIS_HOST=$(echo $REDIS_URL | sed -n 's/.*:\/\/\([^\/]*\).*/\1/p' | cut -d: -f1)
fi
REDIS_PORT=$(echo $REDIS_URL | sed -n 's/.*:\([0-9]*\).*/\1/p')
if [ -z "$REDIS_PORT" ]; then
    REDIS_PORT=6379
fi

# Wait for PostgreSQL
if ! wait_for_service "$DB_HOST" "$DB_PORT" "PostgreSQL"; then
    echo -e "${RED}Cannot start without database${NC}"
    exit 1
fi

# Wait for Redis
if ! wait_for_service "$REDIS_HOST" "$REDIS_PORT" "Redis"; then
    echo -e "${RED}Cannot start without Redis${NC}"
    exit 1
fi

# Check if ClamAV is enabled and wait for it
if [ "${CLAMAV_ENABLED}" = "true" ]; then
    CLAMAV_HOST=${CLAMAV_HOST:-localhost}
    CLAMAV_PORT=${CLAMAV_PORT:-3310}
    
    echo -e "${YELLOW}ClamAV enabled, checking availability...${NC}"
    if wait_for_service "$CLAMAV_HOST" "$CLAMAV_PORT" "ClamAV"; then
        echo -e "${GREEN}✓ ClamAV is available${NC}"
    else
        echo -e "${YELLOW}⚠ ClamAV not available, virus scanning will be disabled${NC}"
        export CLAMAV_ENABLED=false
    fi
fi

# Create upload directory if it doesn't exist (for local storage)
if [ "${STORAGE_TYPE}" = "local" ]; then
    UPLOAD_DIR=${UPLOAD_DIR:-./uploads}
    mkdir -p "$UPLOAD_DIR"
    echo -e "${GREEN}✓ Upload directory ready: $UPLOAD_DIR${NC}"
fi

# Determine the backend binary location
BACKEND_BIN=""
if [ -f "./clovalink_backend" ]; then
    BACKEND_BIN="./clovalink_backend"
elif [ -f "./target/release/clovalink_api" ]; then
    BACKEND_BIN="./target/release/clovalink_api"
elif [ -f "/app/clovalink_backend" ]; then
    BACKEND_BIN="/app/clovalink_backend"
else
    echo -e "${RED}Error: Backend binary not found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Backend binary found: $BACKEND_BIN${NC}"

# Start the backend
echo -e "${GREEN}Starting ClovaLink Backend Server...${NC}"
exec $BACKEND_BIN
