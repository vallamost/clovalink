# Docker vs Native Deployment Comparison

This document helps you choose between Docker and native deployment for ClovaLink.

## TL;DR

**Use Docker if:**
- You want the easiest setup and updates
- You manage multiple environments
- You need consistent deployment across different systems
- You're comfortable with containers

**Use Native if:**
- You need maximum performance
- You have limited resources
- You prefer direct system integration
- You want full control over each component

## Detailed Comparison

### Installation & Setup

| Aspect | Docker | Native |
|--------|--------|--------|
| **Initial Setup** | ⭐⭐⭐⭐⭐ One command | ⭐⭐⭐ Multiple steps |
| **Time to Deploy** | 5-10 minutes | 15-30 minutes |
| **Dependencies** | Only Docker required | Must install all dependencies |
| **Configuration** | Single docker-compose.yml | Multiple config files |
| **Automation** | install.sh script | install-native.sh script |

**Winner: Docker** - Significantly easier and faster to set up.

### Performance

| Metric | Docker | Native |
|--------|--------|--------|
| **CPU Overhead** | ~3-5% | 0% |
| **Memory Overhead** | ~100-200 MB | 0 MB |
| **I/O Performance** | Good (volume overhead) | Excellent (direct) |
| **Network Latency** | +0.1-0.5 ms | 0 ms |
| **Startup Time** | 10-15 seconds | 5-8 seconds |

**Winner: Native** - Better performance, especially on resource-constrained systems.

### Resource Usage

Example workload: 100 concurrent users, 10GB of files

| Resource | Docker | Native | Savings |
|----------|--------|--------|---------|
| **RAM** | ~1.5 GB | ~1.2 GB | 300 MB |
| **CPU (idle)** | ~5% | ~2% | 3% |
| **Disk (system)** | ~2 GB | ~500 MB | 1.5 GB |

**Winner: Native** - Lower resource consumption.

### Operations & Maintenance

| Task | Docker | Native |
|------|--------|--------|
| **View Logs** | `docker compose logs -f` | `journalctl -u clovalink-backend -f` |
| **Restart Service** | `docker compose restart` | `systemctl restart clovalink-backend` |
| **Update** | Pull new image, restart | Rebuild from source |
| **Rollback** | Easy (image tags) | Manual (backup binaries) |
| **Debug** | `docker exec` required | Direct access |
| **Health Check** | Built-in Docker health | Manual monitoring |

**Winner: Docker** - Simpler operations, easier updates and rollbacks.

### System Integration

| Feature | Docker | Native |
|---------|--------|--------|
| **Systemd Integration** | Limited | Full |
| **Log Management** | Docker logs | journald/syslog |
| **Monitoring Tools** | Container-specific | Standard Linux tools |
| **Backup** | Volume snapshots | Standard file backup |
| **Firewall Rules** | Container network | Standard iptables/ufw |
| **Resource Limits** | Docker constraints | systemd limits |

**Winner: Native** - Better integration with system tools and workflows.

### Security

| Aspect | Docker | Native |
|--------|--------|--------|
| **Isolation** | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐⭐ Good |
| **Attack Surface** | Container runtime + app | App only |
| **Updates** | Single image update | Multiple packages |
| **Secrets Management** | Environment or secrets | Environment files |
| **User Privileges** | Container user | System user |
| **Network Isolation** | Container network | Host network |

**Winner: Docker** - Better isolation, though native can be hardened.

### Scalability

| Scenario | Docker | Native |
|----------|--------|--------|
| **Single Server** | Both work well | Both work well |
| **Multiple Servers** | Easy with orchestration | Manual clustering |
| **Auto-scaling** | Kubernetes, Swarm | Custom solution |
| **Load Balancing** | Built-in options | Manual nginx/haproxy |
| **High Availability** | Docker Swarm/K8s | Custom setup |

**Winner: Docker** - Better for multi-server deployments.

### Development Workflow

| Task | Docker | Native |
|------|--------|--------|
| **Dev Environment** | docker-compose.yml | Manual setup |
| **Testing Changes** | Rebuild image | cargo build |
| **CI/CD Integration** | Excellent | Good |
| **Environment Parity** | Identical | OS-dependent |
| **Multiple Versions** | Easy (tags) | Manual management |

**Winner: Docker** - Better for development teams.

### Cost Analysis

**VPS Deployment (4GB RAM, 2 CPU)**

| Deployment | Monthly Cost | Notes |
|------------|-------------|-------|
| **Docker** | $20-25 | Standard VPS |
| **Native** | $15-20 | Can use smaller VPS |

**Dedicated Server (8GB RAM, 4 CPU)**

| Deployment | Instances | Notes |
|------------|-----------|-------|
| **Docker** | 3-4 instances | Container overhead |
| **Native** | 4-5 instances | More efficient |

**Winner: Native** - Can run on smaller/cheaper hardware.

### Troubleshooting

| Issue Type | Docker | Native |
|------------|--------|--------|
| **Service Won't Start** | Check logs easily | Check systemd status |
| **Connection Issues** | Network inspection | Standard netstat/tcpdump |
| **Performance Issues** | Container stats | Standard top/htop |
| **Disk Space** | `docker system df` | `du -sh` |
| **Process Inspection** | `docker exec` | Direct access |

**Winner: Native** - Standard Linux tools work directly.

## Use Case Recommendations

### Use Docker When:

1. **Development Team**
   - Multiple developers need identical environments
   - Quick onboarding is important
   - You use CI/CD pipelines

2. **Managed Infrastructure**
   - Using Kubernetes or Docker Swarm
   - Need to scale horizontally
   - Want blue-green deployments

3. **Multi-tenant Hosting**
   - Running many isolated ClovaLink instances
   - Need strong isolation between tenants
   - Container orchestration benefits

4. **Quick Evaluation**
   - Testing ClovaLink features
   - Proof of concept
   - Short-term projects

### Use Native When:

1. **Production Single Server**
   - One stable instance
   - Maximum performance needed
   - Limited resources (1-2 GB RAM)

2. **Legacy Infrastructure**
   - Existing monitoring/alerting with systemd
   - Standard Linux workflows
   - No Docker expertise in team

3. **Embedded/Edge Devices**
   - ARM devices
   - Limited storage
   - IoT deployments

4. **Cost Optimization**
   - Running on minimal VPS
   - Every MB of RAM matters
   - Long-term hosting (3+ years)

## Migration Path

### Docker → Native

1. Export data:
   ```bash
   docker compose exec postgres pg_dump clovalink > backup.sql
   docker compose exec backend tar -czf uploads.tar.gz /app/uploads
   ```

2. Copy .env configuration

3. Install native deployment:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/ClovaLink/ClovaLink/main/deployment/install-native.sh | sudo bash
   ```

4. Import data:
   ```bash
   psql -U clovalink -d clovalink < backup.sql
   tar -xzf uploads.tar.gz -C /opt/clovalink/backend/
   ```

### Native → Docker

1. Export data:
   ```bash
   pg_dump -U clovalink clovalink > backup.sql
   tar -czf uploads.tar.gz /opt/clovalink/backend/uploads
   ```

2. Copy .env configuration

3. Install Docker deployment:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/ClovaLink/ClovaLink/main/install.sh | bash
   ```

4. Import data:
   ```bash
   docker compose exec -T postgres psql -U postgres clovalink < backup.sql
   docker compose exec backend tar -xzf - -C /app/uploads < uploads.tar.gz
   ```

## Hybrid Approach

You can also mix approaches:

- **Database/Redis**: Native (better performance)
- **Application**: Docker (easy updates)

Example docker-compose.yml for hybrid:

```yaml
services:
  backend:
    image: ghcr.io/clovalink/clovalink-backend:latest
    environment:
      - DATABASE_URL=postgres://clovalink:password@host.docker.internal:5432/clovalink
      - REDIS_URL=redis://host.docker.internal:6379
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

## Decision Matrix

Rate importance (1-5) and multiply by score difference:

| Factor | Importance | Docker Score | Native Score | Weighted |
|--------|-----------|--------------|--------------|----------|
| Easy Setup | ×____ | 5 | 3 | +______ |
| Performance | ×____ | 3 | 5 | -______ |
| Resource Usage | ×____ | 3 | 5 | -______ |
| Easy Updates | ×____ | 5 | 2 | +______ |
| System Integration | ×____ | 3 | 5 | -______ |
| Scalability | ×____ | 5 | 3 | +______ |
| Cost | ×____ | 3 | 5 | -______ |

**Positive total = Docker, Negative total = Native**

## Summary

Both approaches are fully supported and production-ready:

- **Docker**: Best for teams, development, and multi-server deployments
- **Native**: Best for single-server production, performance, and cost optimization

The good news: **ClovaLink's unified startup logic means you can switch between them** without significant code changes.

## Questions?

- Docker issues: Use GitHub issues with `deployment:docker` label
- Native issues: Use GitHub issues with `deployment:native` label
- Documentation: See [NATIVE-DEPLOYMENT.md](NATIVE-DEPLOYMENT.md) and main README.md
