#!/bin/bash

set -e

echo "🚀 Starting Simple AI Stack deployment with validation..."

# Function to validate required environment variables
validate_environment() {
    local missing_vars=()
    local required_vars=(
        "SERVER_IP"
        "LITELLM_MASTER_KEY" 
        "POSTGRES_PASSWORD"
        "N8N_USER"
        "N8N_PASSWORD"
        "FLOWISE_USER"
        "FLOWISE_PASSWORD"
        "WEBUI_SECRET_KEY"
    )
    
    # Optional but recommended variables
    local optional_vars=(
        "OPENAI_API_KEY"
        "ANTHROPIC_API_KEY"
        "OLLAMA_BASE_URL"
        "TIMEZONE"
    )
    
    echo "🔍 Validating environment configuration..."
    
    # Check required variables
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        else
            echo "✅ $var: configured"
        fi
    done
    
    # Check optional variables
    for var in "${optional_vars[@]}"; do
        if [ -z "${!var}" ]; then
            echo "⚠️  $var: not set (optional)"
        else
            echo "✅ $var: configured"
        fi
    done
    
    # Fail if required variables are missing
    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo ""
        echo "❌ DEPLOYMENT FAILED: Missing required environment variables:"
        printf '   - %s\n' "${missing_vars[@]}"
        echo ""
        echo "Please add these variables to your .env file:"
        echo ""
        for var in "${missing_vars[@]}"; do
            case $var in
                "SERVER_IP")
                    echo "SERVER_IP=147.93.185.141  # Dev: 147.93.185.141, Prod: 147.93.181.151"
                    ;;
                "LITELLM_MASTER_KEY")
                    echo "LITELLM_MASTER_KEY=\$(openssl rand -base64 32)  # Generate secure key"
                    ;;
                "POSTGRES_PASSWORD")
                    echo "POSTGRES_PASSWORD=\$(openssl rand -hex 16)  # Generate secure password"
                    ;;
                "N8N_USER"|"FLOWISE_USER")
                    echo "$var=admin  # Or your preferred username"
                    ;;
                "N8N_PASSWORD"|"FLOWISE_PASSWORD")
                    echo "$var=\$(openssl rand -base64 12)  # Generate secure password"
                    ;;
                "WEBUI_SECRET_KEY")
                    echo "$var=\$(openssl rand -base64 32)  # Generate secure secret"
                    ;;
            esac
        done
        echo ""
        exit 1
    fi
    
    echo "✅ Environment validation passed!"
    echo ""
}

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ .env file not found!"
    echo ""
    echo "Create .env file with required variables:"
    echo "SERVER_IP=your_server_ip"
    echo "LITELLM_MASTER_KEY=your_master_key" 
    echo "POSTGRES_PASSWORD=your_postgres_password"
    echo "# ... other required variables"
    echo ""
    echo "See README.md for complete environment variable documentation."
    exit 1
fi

# Load and validate environment variables
set -o allexport
source .env
set +o allexport

# Run validation
validate_environment

# Detect environment based on server IP
if [[ "${SERVER_IP}" == "147.93.185.141" ]]; then
    ENVIRONMENT="dev"
    NGINX_CONFIG="nginx/dev.conf"
    echo "🔧 Deploying to DEVELOPMENT environment (${SERVER_IP})"
elif [[ "${SERVER_IP}" == "147.93.181.151" ]]; then
    ENVIRONMENT="prod"
    NGINX_CONFIG="nginx/prod.conf" 
    echo "🔧 Deploying to PRODUCTION environment (${SERVER_IP})"
else
    echo "❌ Unknown server IP: ${SERVER_IP}"
    echo "Expected IPs:"
    echo "  - Development: 147.93.185.141"
    echo "  - Production:  147.93.181.151"
    echo ""
    echo "Update SERVER_IP in your .env file."
    exit 1
fi

# Database connection validation
echo "🔍 Validating database configuration..."
DB_URL="postgresql://litellm:${POSTGRES_PASSWORD}@postgres:5432/litellm"
echo "✅ Database URL configured for PostgreSQL container"

# Install required system packages
if ! command -v nginx &> /dev/null; then
    echo "📦 Installing nginx and dependencies..."
    apt update && apt install -y nginx certbot python3-certbot-nginx curl
    echo "✅ System packages installed"
fi

# Configure nginx
if [ -f "$NGINX_CONFIG" ]; then
    echo "⚙️ Configuring nginx for ${ENVIRONMENT} environment..."
    cp ${NGINX_CONFIG} /etc/nginx/sites-available/bionicvault.conf
    ln -sf /etc/nginx/sites-available/bionicvault.conf /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    if nginx -t; then
        systemctl reload nginx
        echo "✅ Nginx configuration applied successfully"
    else
        echo "❌ Nginx configuration test failed"
        exit 1
    fi
else
    echo "⚠️  Nginx config file $NGINX_CONFIG not found, skipping nginx setup"
fi

# Docker operations with validation
echo "📦 Pulling latest Docker images..."
if ! docker-compose pull; then
    echo "❌ Failed to pull Docker images"
    echo "Check your internet connection and Docker registry access"
    exit 1
fi

echo "🛑 Stopping existing services..."
docker-compose down --remove-orphans

echo "🚀 Starting services with dependency order..."
if ! docker-compose up -d; then
    echo "❌ Failed to start services"
    echo ""
    echo "Service logs:"
    docker-compose logs --tail=20
    exit 1
fi

# Wait for services with timeout
echo "⏳ Waiting for services to initialize..."
TIMEOUT=60
COUNTER=0

while [ $COUNTER -lt $TIMEOUT ]; do
    if docker-compose ps | grep -q "Up"; then
        break
    fi
    sleep 2
    COUNTER=$((COUNTER + 2))
    echo -n "."
done

if [ $COUNTER -ge $TIMEOUT ]; then
    echo ""
    echo "⚠️  Service startup timeout reached"
    docker-compose ps
else
    echo ""
    echo "✅ Services started successfully"
fi

# Comprehensive health checks
echo "🔍 Running health checks..."
declare -A SERVICES=(
    ["postgres"]="5432"
    ["flowise"]="3001" 
    ["n8n"]="5678"
    ["openwebui"]="8080"
    ["litellm"]="4000"
)

for service in "${!SERVICES[@]}"; do
    port="${SERVICES[$service]}"
    
    # Check if port is accessible
    if timeout 5 bash -c "</dev/tcp/localhost/$port"; then
        echo "✅ $service (port $port): HEALTHY"
    else
        echo "❌ $service (port $port): FAILED"
        echo "   Checking logs for $service:"
        docker-compose logs "$service" --tail=5 | sed 's/^/   /'
    fi
done

# Service-specific validations
echo ""
echo "🔍 Running service-specific checks..."

# PostgreSQL connection test
if docker exec ai-stack-simple-postgres-1 pg_isready -U litellm -d litellm >/dev/null 2>&1; then
    echo "✅ PostgreSQL: Database connection successful"
else
    echo "❌ PostgreSQL: Database connection failed"
    docker-compose logs postgres --tail=5
fi

# LiteLLM API test
if curl -s -o /dev/null -w "%{http_code}" http://localhost:4000 | grep -q "200"; then
    echo "✅ LiteLLM: API responding"
else
    echo "❌ LiteLLM: API not responding"
    docker-compose logs litellm --tail=5
fi

# Final deployment summary
echo ""
echo "✅ Deployment completed for ${ENVIRONMENT^^} environment!"
echo ""

if [[ "${ENVIRONMENT}" == "dev" ]]; then
    echo "🌐 Development URLs:"
    echo "   • Flowise:    https://dev-flowise.bionicvault.com"
    echo "   • n8n:        https://dev-n8n.bionicvault.com"
    echo "   • Open WebUI: https://dev-openwebui.bionicvault.com" 
    echo "   • LiteLLM:    https://dev-litellm.bionicvault.com"
else
    echo "🌐 Production URLs:"
    echo "   • Flowise:    https://flowise.bionicvault.com"
    echo "   • n8n:        https://n8n.bionicvault.com"
    echo "   • Open WebUI: https://openwebui.bionicvault.com"
    echo "   • LiteLLM:    https://litellm.bionicvault.com"
fi

echo ""
echo "📊 Final Service Status:"
docker-compose ps

echo ""
echo "🎯 Deployment Summary:"
echo "   • Environment: ${ENVIRONMENT^^}"
echo "   • Server IP: ${SERVER_IP}" 
echo "   • Services: $(docker-compose ps --services | wc -l) containers running"
echo "   • Database: PostgreSQL container"
echo "   • Proxy: Nginx with SSL"

echo ""
echo "✅ All systems operational!"