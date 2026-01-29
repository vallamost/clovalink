# ClovaLink Deployment Files

This directory contains deployment configurations and scripts for running ClovaLink without Docker.

## Directory Structure

```
deployment/
├── systemd/                    # Systemd service files
│   ├── clovalink-backend.service
│   └── clovalink-frontend.service
├── scripts/                    # Helper scripts
│   ├── start-backend.sh       # Backend startup script (Docker/native compatible)
│   └── validate-env.sh        # Environment validation script
├── nginx.conf                 # Nginx configuration for frontend
├── install-native.sh          # Automated installer for native deployment
├── NATIVE-DEPLOYMENT.md       # Comprehensive deployment guide
└── README.md                  # This file
```

## Quick Start

### Automated Installation

For a quick native deployment on Ubuntu/Debian:

```bash
curl -fsSL https://raw.githubusercontent.com/ClovaLink/ClovaLink/main/deployment/install-native.sh | sudo bash
```

### Manual Installation

See [NATIVE-DEPLOYMENT.md](NATIVE-DEPLOYMENT.md) for detailed manual installation instructions.

## Files Overview

### Systemd Services

- **clovalink-backend.service** - Systemd unit for the Rust backend API server
- **clovalink-frontend.service** - Systemd unit for Nginx serving the React frontend

### Scripts

- **start-backend.sh** - Shared startup script for the backend that:
  - Validates environment variables
  - Waits for PostgreSQL and Redis to be ready
  - Checks for ClamAV if enabled
  - Starts the backend binary
  - Works in both Docker and native environments

- **validate-env.sh** - Environment validation script that:
  - Checks required environment variables
  - Validates URL formats
  - Verifies secret strength
  - Warns about insecure configurations

### Configuration

- **nginx.conf** - Nginx configuration that:
  - Serves the frontend static files
  - Proxies API requests to the backend
  - Handles large file uploads
  - Includes security headers

### Installation

- **install-native.sh** - Automated installer that:
  - Detects OS and installs dependencies
  - Sets up PostgreSQL and Redis
  - Builds ClovaLink from source
  - Configures systemd services
  - Generates secure defaults

## Deployment Approaches

ClovaLink supports two deployment approaches:

### 1. Docker Deployment (Default)

Uses Docker Compose for containerized deployment. See main README.md.

**Pros:**
- Easy to install and update
- Consistent across environments
- Excellent isolation

**Cons:**
- Container overhead
- Requires Docker

### 2. Native Deployment (This Directory)

Runs directly on the host system using systemd services.

**Pros:**
- Better performance (no container overhead)
- Lower resource usage
- Direct system integration
- Easier debugging

**Cons:**
- More complex setup
- OS-dependent
- Manual updates required

## Interoperability

The deployment files are designed to maximize interoperability between Docker and native deployments:

### Shared Components

1. **Environment Variables** - Both deployments use the same `.env` format
2. **Startup Logic** - `start-backend.sh` works in both environments
3. **Configuration** - Same configuration structure and validation

### Minimal Branching

The codebase avoids deployment-specific code paths:

- Backend uses environment variables for all configuration
- Frontend is built the same way for both deployments
- Database migrations are identical
- Storage backends work the same way

### Migration Between Deployments

You can migrate between Docker and native deployments:

**Docker → Native:**
1. Export database: `docker compose exec postgres pg_dump ...`
2. Export .env configuration
3. Install native deployment
4. Import database and configuration

**Native → Docker:**
1. Export database: `pg_dump ...`
2. Copy .env configuration
3. Install Docker deployment
4. Import database and configuration

## Service Management

### Native Deployment

```bash
# Start services
sudo systemctl start clovalink-backend
sudo systemctl start clovalink-frontend

# Stop services
sudo systemctl stop clovalink-backend
sudo systemctl stop clovalink-frontend

# Restart services
sudo systemctl restart clovalink-backend
sudo systemctl restart clovalink-frontend

# View logs
sudo journalctl -u clovalink-backend -f
sudo journalctl -u clovalink-frontend -f

# Check status
sudo systemctl status clovalink-backend
sudo systemctl status clovalink-frontend
```

### Docker Deployment

```bash
# Start services
docker compose up -d

# Stop services
docker compose down

# Restart services
docker compose restart

# View logs
docker compose logs -f

# Check status
docker compose ps
```

## Troubleshooting

### Native Deployment Issues

**Service won't start:**
```bash
# Check logs
sudo journalctl -u clovalink-backend -n 50

# Validate configuration
bash deployment/scripts/validate-env.sh /opt/clovalink/backend/.env

# Check dependencies
sudo systemctl status postgresql
sudo systemctl status redis-server
```

**Permission errors:**
```bash
# Fix ownership
sudo chown -R clovalink:clovalink /opt/clovalink
sudo chown -R clovalink:clovalink /var/log/clovalink
```

**Port conflicts:**
```bash
# Check what's using the port
sudo lsof -i :3000  # Backend
sudo lsof -i :8080  # Frontend
```

## Security

### Hardening Checklist

- [ ] Use strong JWT_SECRET (64+ characters)
- [ ] Use strong database passwords
- [ ] Enable encryption for local storage
- [ ] Use HTTPS in production
- [ ] Enable firewall (ufw/iptables)
- [ ] Regular system updates
- [ ] Restrict .env file permissions (600)
- [ ] Enable ClamAV for virus scanning
- [ ] Configure log rotation
- [ ] Regular backups

### Systemd Security Features

Both service files include security hardening:

- `NoNewPrivileges=true` - Prevents privilege escalation
- `PrivateTmp=true` - Isolated /tmp directory
- `ProtectSystem=strict` - Read-only filesystem
- `ProtectHome=true` - No access to home directories
- `ReadWritePaths=...` - Only specific paths are writable

## Documentation

- [NATIVE-DEPLOYMENT.md](NATIVE-DEPLOYMENT.md) - Complete deployment guide
- [../README.md](../README.md) - Main project README
- [../backend/TESTING.md](../backend/TESTING.md) - Testing guide

## Support

For issues or questions:

- GitHub Issues: https://github.com/ClovaLink/ClovaLink/issues
- Documentation: https://github.com/ClovaLink/ClovaLink
- Hosted Version: https://clovalink.com
