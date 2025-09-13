# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

This is a containerized AI stack deployment system that orchestrates multiple AI/automation services:

- **PostgreSQL**: Database backend for LiteLLM proxy
- **LiteLLM**: Universal LLM proxy server with database persistence
- **n8n**: Workflow automation platform
- **Flowise**: Low-code AI application builder
- **OpenWebUI**: Chat interface for LLM interactions
- **Nginx**: Reverse proxy with SSL termination

The stack supports two environments (dev/prod) with automatic environment detection based on SERVER_IP configuration.

## Key Commands

### Deployment
```bash
# Full deployment with environment validation
./deploy.sh

# Manual Docker operations
docker-compose up -d
docker-compose down --remove-orphans
docker-compose pull
```

### Service Management
```bash
# Check service status
docker-compose ps

# View logs
docker-compose logs [service-name]
docker-compose logs --tail=20

# Health checks for individual services
docker exec ai-stack-simple-postgres-1 pg_isready -U litellm_user -d litellm
curl -f http://localhost:4000/  # LiteLLM API
```

### Environment Management
```bash
# Validate environment configuration
source .env && ./deploy.sh

# Test database connectivity
docker exec ai-stack-simple-postgres-1 pg_isready -U litellm_user -d litellm

# Test service endpoints
curl -H "Authorization: Bearer $LITELLM_MASTER_KEY" http://localhost:4000/health
```

## Environment Configuration

The system uses environment-based configuration with comprehensive validation:

### Required Variables
- `SERVER_IP`: Determines deployment environment (dev: 147.93.185.141, prod: 147.93.181.151)
- `LITELLM_MASTER_KEY`: Authentication key for LiteLLM proxy
- `POSTGRES_PASSWORD`: PostgreSQL database password
- `N8N_USER/N8N_PASSWORD`: n8n authentication credentials
- `FLOWISE_USER/FLOWISE_PASSWORD`: Flowise authentication credentials
- `WEBUI_SECRET_KEY`: OpenWebUI session secret

### Optional Variables
- `OPENAI_API_KEY/ANTHROPIC_API_KEY`: LLM provider credentials
- `OLLAMA_BASE_URL`: Local Ollama instance URL
- `TIMEZONE`: Container timezone setting

Environment validation occurs during deployment and will fail fast with specific guidance for missing variables.

## Service Architecture

### Port Mapping
- PostgreSQL: 5432
- LiteLLM: 4000 
- n8n: 5678
- Flowise: 3001 (mapped to container port 3000)
- OpenWebUI: 8080

### Data Persistence
All services use Docker volumes for data persistence:
- `postgres_data`: Database storage
- `litellm_data`: LiteLLM configuration and logs
- `n8n_data`: Workflow definitions
- `flowise_data`: AI application configurations
- `openwebui_data`: Chat history and settings

### Network Configuration
Services communicate via Docker network `ai-simple` with dependency management ensuring PostgreSQL starts before LiteLLM.

## Deployment Process

The `deploy.sh` script performs:

1. Environment variable validation with specific error messages
2. Environment detection (dev/prod) based on SERVER_IP
3. Nginx configuration deployment for SSL proxy
4. Docker image updates and container orchestration
5. Service health checks with timeout handling
6. Comprehensive status reporting

## SSL and Domain Configuration

- **Development**: `dev-*.bionicvault.com` subdomains
- **Production**: `*.bionicvault.com` subdomains

Nginx configurations are environment-specific and located in `nginx/dev.conf` and `nginx/prod.conf`.

## CI/CD Integration

GitHub Actions workflow (`.github/workflows/deploy.yml`):
- Automatic deployment to dev environment on `dev` branch pushes
- Manual production deployment via workflow dispatch
- SSH-based deployment to configured servers

## Troubleshooting

When services fail to start:
1. Check environment variable configuration
2. Review Docker container logs for specific services
3. Verify database connectivity
4. Test individual service health endpoints
5. Check nginx configuration and SSL certificates

The deployment script provides comprehensive error reporting and suggests specific remediation steps for common failure scenarios.