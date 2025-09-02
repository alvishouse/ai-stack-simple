#!/bin/bash

set -e

echo "🚀 Starting Smart AI Stack deployment..."

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ .env file not found! Please create it from .env.example"
    exit 1
fi

# Load environment variables
export $(cat .env | grep -v '^#' | xargs)

# Detect environment based on server IP
if [[ "${SERVER_IP}" == "147.93.185.141" ]]; then
    ENVIRONMENT="dev"
    NGINX_CONFIG="nginx/dev.conf"
    DEPLOYMENT_STRATEGY="full"  # Fast deployment for dev
    echo "🔧 Deploying to DEVELOPMENT environment"
elif [[ "${SERVER_IP}" == "147.93.181.151" ]]; then
    ENVIRONMENT="prod"
    NGINX_CONFIG="nginx/prod.conf"
    DEPLOYMENT_STRATEGY="smart"  # Smart deployment for prod
    echo "🔧 Deploying to PRODUCTION environment"
else
    echo "❌ Unknown server IP: ${SERVER_IP}"
    echo "Expected: 147.93.185.141 (dev) or 147.93.181.151 (prod)"
    exit 1
fi

# Install nginx if not present
if ! command -v nginx &> /dev/null; then
    echo "📦 Installing nginx..."
    apt update && apt install -y nginx
fi

# Copy environment-specific nginx configuration
echo "⚙️ Setting up nginx for ${ENVIRONMENT}..."
cp ${NGINX_CONFIG} /etc/nginx/sites-available/bionicvault.conf
ln -sf /etc/nginx/sites-available/bionicvault.conf /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

# Function to detect what changed
detect_changes() {
    # Check if this is the first deployment (no previous commit)
    if ! git rev-parse HEAD~1 >/dev/null 2>&1; then
        echo "all"  # First deployment - deploy everything
        return
    fi
    
    # Get list of changed files
    CHANGED_FILES=$(git diff --name-only HEAD~1)
    echo "📋 Changed files: $CHANGED_FILES"
    
    # Check for infrastructure changes (require full restart)
    if echo "$CHANGED_FILES" | grep -E "(docker-compose|\.env|nginx/|deploy\.sh)" > /dev/null; then
        echo "infrastructure"
        return
    fi
    
    # Check for service-specific changes
    CHANGED_SERVICES=""
    if echo "$CHANGED_FILES" | grep -E "(litellm|LiteLLM)" > /dev/null; then
        CHANGED_SERVICES="$CHANGED_SERVICES litellm"
    fi
    if echo "$CHANGED_FILES" | grep -E "(flowise|Flowise)" > /dev/null; then
        CHANGED_SERVICES="$CHANGED_SERVICES flowise"
    fi
    if echo "$CHANGED_FILES" | grep -E "(openwebui|open-webui|OpenWebUI)" > /dev/null; then
        CHANGED_SERVICES="$CHANGED_SERVICES openwebui"
    fi
    if echo "$CHANGED_FILES" | grep -E "(n8n|N8N)" > /dev/null; then
        CHANGED_SERVICES="$CHANGED_SERVICES n8n"
    fi
    
    if [[ -n "$CHANGED_SERVICES" ]]; then
        echo "$CHANGED_SERVICES"
    else
        echo "none"  # No service changes detected
    fi
}

# Function to wait for service health using Docker health checks
wait_for_service_health() {
    local service=$1
    local max_attempts=30
    local attempt=1
    
    echo "⏳ Waiting for $service to be healthy..."
    while [ $attempt -le $max_attempts ]; do
        local health_status=$(docker inspect --format='{{.State.Health.Status}}' "${service}" 2>/dev/null || echo "no-healthcheck")
        
        if [[ "$health_status" == "healthy" ]]; then
            echo "✅ $service is healthy"
            return 0
        elif [[ "$health_status" == "no-healthcheck" ]]; then
            # Fallback to port check if no health check defined
            local port
            case $service in
                "ai-stack-simple-litellm-1"|"litellm") port="4000" ;;
                "ai-stack-simple-flowise-1"|"flowise") port="3001" ;;
                "ai-stack-simple-openwebui-1"|"openwebui") port="8080" ;;
                "ai-stack-simple-n8n-1"|"n8n") port="5678" ;;
                *) echo "⚠️  Unknown service for port check: $service"; return 0 ;;
            esac
            
            if curl -f -s http://localhost:$port > /dev/null 2>&1; then
                echo "✅ $service is responding on port $port"
                return 0
            fi
        fi
        
        echo "⏳ $service health: $health_status (attempt $attempt/$max_attempts)"
        sleep 3
        attempt=$((attempt + 1))
    done
    
    echo "⚠️  $service didn't become healthy, but continuing..."
    return 0  # Don't fail deployment, just warn
}

# Function to restart specific services with rolling strategy
rolling_restart_services() {
    local services_to_restart="$1"
    
    echo "🔄 Rolling restart for services: $services_to_restart"
    
    # Pull latest images first
    echo "📦 Pulling Docker images..."
    docker-compose pull $services_to_restart
    
    # Restart each service individually
    for service in $services_to_restart; do
        echo "🔄 Rolling restart for $service..."
        
        # Restart individual service (--no-deps prevents restarting dependencies)
        docker-compose up -d --no-deps --force-recreate $service
        
        # Wait for service to be healthy
        wait_for_service_health $service
        
        # Small delay between services
        sleep 5
    done
}

# Main deployment logic
CHANGES=$(detect_changes)
echo "🔍 Change detection result: $CHANGES"

if [[ "${DEPLOYMENT_STRATEGY}" == "full" ]]; then
    # Development environment - fast full deployment
    echo "🛑 Full stack restart for development..."
    docker-compose pull
    docker-compose down --remove-orphans
    docker-compose up -d
    sleep 30
    
elif [[ "${CHANGES}" == "all" || "${CHANGES}" == "infrastructure" ]]; then
    # Production environment - infrastructure changes require full restart but with rolling strategy
    echo "🔄 Infrastructure changes detected - full rolling restart..."
    docker-compose pull
    
    # Define all services for rolling restart
    ALL_SERVICES="litellm flowise openwebui n8n"
    rolling_restart_services "$ALL_SERVICES"
    
elif [[ "${CHANGES}" == "none" ]]; then
    # No changes detected - just ensure everything is up
    echo "✅ No changes detected - ensuring all services are running..."
    docker-compose pull
    docker-compose up -d
    
else
    # Selective service restart
    echo "🎯 Selective restart for changed services: $CHANGES"
    rolling_restart_services "$CHANGES"
fi

echo ""
echo "✅ Smart deployment completed for ${ENVIRONMENT^^} environment!"
echo "📊 Change detection: $CHANGES"
echo ""

# Display URLs
if [[ "${ENVIRONMENT}" == "dev" ]]; then
    echo "🌐 Development URLs:"
    echo "• Flowise:    http://dev-flowise.bionicvault.com"
    echo "• n8n:        http://dev-n8n.bionicvault.com" 
    echo "• Open WebUI: http://dev-openwebui.bionicvault.com"
    echo "• LiteLLM:    http://dev-litellm.bionicvault.com"
else
    echo "🌐 Production URLs:"
    echo "• Flowise:    http://flowise.bionicvault.com"
    echo "• n8n:        http://n8n.bionicvault.com" 
    echo "• Open WebUI: http://openwebui.bionicvault.com"
    echo "• LiteLLM:    http://litellm.bionicvault.com"
fi

echo ""
echo "📈 Service Status:"
docker-compose ps

echo ""
echo "🏥 Health Check Status:"
for service in litellm flowise openwebui n8n; do
    container_name=$(docker-compose ps -q $service 2>/dev/null)
    if [[ -n "$container_name" ]]; then
        health_status=$(docker inspect --format='{{.State.Health.Status}}' $container_name 2>/dev/null || echo "no-healthcheck")
        echo "• $service: $health_status"
    fi
done