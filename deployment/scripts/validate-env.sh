#!/bin/bash
#
# ClovaLink Environment Validation Script
# Validates .env file and checks for common configuration issues
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}ClovaLink Environment Validation${NC}"
echo ""

# Find .env file
ENV_FILE="${1:-.env}"

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error: .env file not found at $ENV_FILE${NC}"
    echo "Usage: $0 [path-to-.env]"
    exit 1
fi

echo -e "${BLUE}Checking: $ENV_FILE${NC}"
echo ""

# Load .env file
set -a
source "$ENV_FILE"
set +a

# Track validation status
ERRORS=0
WARNINGS=0

# Function to check required variable
check_required() {
    local var_name=$1
    local var_value="${!var_name}"
    
    if [ -z "$var_value" ]; then
        echo -e "${RED}✗ $var_name is not set${NC}"
        ERRORS=$((ERRORS + 1))
        return 1
    else
        echo -e "${GREEN}✓ $var_name is set${NC}"
        return 0
    fi
}

# Function to check optional variable
check_optional() {
    local var_name=$1
    local var_value="${!var_name}"
    
    if [ -z "$var_value" ]; then
        echo -e "${YELLOW}⚠ $var_name is not set (optional)${NC}"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "${GREEN}✓ $var_name is set${NC}"
    fi
}

# Function to validate URL format
validate_url() {
    local var_name=$1
    local var_value="${!var_name}"
    
    if [[ "$var_value" =~ ^[a-z]+://.+ ]]; then
        echo -e "${GREEN}✓ $var_name has valid URL format${NC}"
    else
        echo -e "${RED}✗ $var_name has invalid URL format: $var_value${NC}"
        ERRORS=$((ERRORS + 1))
    fi
}

# Function to check secret strength
check_secret_strength() {
    local var_name=$1
    local var_value="${!var_name}"
    local min_length=${2:-32}
    
    if [ -z "$var_value" ]; then
        return
    fi
    
    local length=${#var_value}
    if [ $length -lt $min_length ]; then
        echo -e "${YELLOW}⚠ $var_name is shorter than recommended ($length < $min_length characters)${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    if [[ "$var_value" == *"change"* ]] || [[ "$var_value" == *"example"* ]] || [[ "$var_value" == *"dev"* ]]; then
        echo -e "${RED}✗ $var_name appears to use a default/example value${NC}"
        ERRORS=$((ERRORS + 1))
    fi
}

echo -e "${BOLD}Required Variables:${NC}"
check_required "DATABASE_URL"
if [ $? -eq 0 ]; then
    validate_url "DATABASE_URL"
fi

check_required "REDIS_URL"
if [ $? -eq 0 ]; then
    validate_url "REDIS_URL"
fi

check_required "JWT_SECRET"
if [ $? -eq 0 ]; then
    check_secret_strength "JWT_SECRET" 32
fi

echo ""
echo -e "${BOLD}Storage Configuration:${NC}"
STORAGE_TYPE=${STORAGE_TYPE:-local}
echo -e "${BLUE}Storage type: $STORAGE_TYPE${NC}"

if [ "$STORAGE_TYPE" = "local" ]; then
    check_optional "UPLOAD_DIR"
    check_optional "ENCRYPTION_KEY"
    if [ -n "$ENCRYPTION_KEY" ]; then
        check_secret_strength "ENCRYPTION_KEY" 32
    fi
elif [ "$STORAGE_TYPE" = "s3" ]; then
    check_required "S3_BUCKET"
    check_required "S3_REGION"
    check_required "AWS_ACCESS_KEY_ID"
    check_required "AWS_SECRET_ACCESS_KEY"
    check_optional "S3_ENDPOINT"
    check_optional "USE_PRESIGNED_URLS"
fi

echo ""
echo -e "${BOLD}Optional Configuration:${NC}"
check_optional "BASE_URL"
check_optional "CORS_ALLOWED_ORIGINS"
check_optional "ENVIRONMENT"
check_optional "RUST_LOG"

# ClamAV configuration
if [ "${CLAMAV_ENABLED}" = "true" ]; then
    echo ""
    echo -e "${BOLD}ClamAV Configuration:${NC}"
    check_optional "CLAMAV_HOST"
    check_optional "CLAMAV_PORT"
fi

# Replication configuration
if [ "${REPLICATION_ENABLED}" = "true" ]; then
    echo ""
    echo -e "${BOLD}Replication Configuration:${NC}"
    check_required "REPLICATION_ENDPOINT"
    check_required "REPLICATION_BUCKET"
    check_required "REPLICATION_REGION"
    check_required "REPLICATION_ACCESS_KEY"
    check_required "REPLICATION_SECRET_KEY"
    check_optional "REPLICATION_MODE"
fi

# Summary
echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ Validation passed${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}  $WARNINGS warnings (review recommended)${NC}"
    fi
    exit 0
else
    echo -e "${RED}✗ Validation failed${NC}"
    echo -e "${RED}  $ERRORS errors found${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}  $WARNINGS warnings${NC}"
    fi
    exit 1
fi
