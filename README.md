## Quick Setup

### 1. Create Environment File
```bash
# Copy and customize these variables
cat > .env << EOF
SERVER_IP=147.93.185.141
LITELLM_MASTER_KEY=$(openssl rand -base64 32)
POSTGRES_PASSWORD=$(openssl rand -hex 16)
N8N_USER=admin
N8N_PASSWORD=$(openssl rand -base64 12)
FLOWISE_USER=admin  
FLOWISE_PASSWORD=$(openssl rand -base64 12)
WEBUI_SECRET_KEY=$(openssl rand -base64 32)
TIMEZONE=America/New_York
EOF
```

### 2. Add API Keys (Optional)
```bash
# Add your API keys to .env
echo "OPENAI_API_KEY=your_key_here" >> .env
echo "ANTHROPIC_API_KEY=your_key_here" >> .env
```

### 3. Deploy
```bash
# Deployment will validate all required variables
./deploy.sh
```

## Environment Validation

The deployment script automatically validates:

- **Required variables** - Deployment fails if missing
- **Format validation** - Checks for proper values
- **Service-specific requirements** - Database connections, API accessibility  
- **Environment detection** - Automatically detects dev vs prod based on SERVER_IP

### Validation Errors

If deployment fails with missing variables:

```bash
❌ DEPLOYMENT FAILED: Missing required environment variables:
   - POSTGRES_PASSWORD
   - LITELLM_MASTER_KEY
```

The script provides specific guidance for each missing variable.

## Environment-Specific Configuration

### Development Environment (SERVER_IP: 147.93.185.141)
- Services accessible at dev-*.bionicvault.com
- Debug logging enabled
- Relaxed security settings for testing

### Production Environment (SERVER_IP: 147.93.181.151)  
- Services accessible at *.bionicvault.com
- Optimized performance settings
- Enhanced security configuration

## Troubleshooting

### Missing Environment Variables
```bash
# Check what's in your .env file
cat .env

# Validate manually
./deploy.sh
```

### Database Connection Issues
```bash
# Test PostgreSQL connectivity
docker exec ai-stack-simple-postgres-1 pg_isready -U litellm -d litellm

# Check database logs
docker-compose logs postgres
```

### Service Authentication Problems
```bash
# Test LiteLLM with your master key
curl -H "Authorization: Bearer $LITELLM_MASTER_KEY" http://localhost:4000/health

# Check service logs
docker-compose logs litellm
```

## Security Notes

- **Never commit .env files** to version control
- **Generate unique passwords** for each environment  
- **Rotate keys regularly** especially for production
- **Use strong passwords** - minimum 16 characters for database passwords
- **API keys should be scoped** with minimum required permissions

## GitOps Integration

The environment validation integrates seamlessly with your GitHub Actions workflow:

1. **Push to dev branch** → Triggers automatic deployment
2. **Deploy script validates** all environment variables on server
3. **Deployment fails fast** with clear error messages if misconfigured
4. **Manual deployment to production** via workflow dispatch

This prevents the recurring environment synchronization issues by validating configuration at deployment time rather than discovering issues during service startup.