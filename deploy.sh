#!/bin/bash

set -e

echo "🚀 Starting Simple AI Stack deployment..."

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
    echo "🔧 Deploying to DEVELOPMENT environment"
elif [[ "${SERVER_IP}" == "147.93.181.151" ]]; then
    ENVIRONMENT="prod"
    NGINX_CONFIG="nginx/prod.conf"
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

# Pull latest images
echo "📦 Pulling Docker images..."
docker-compose pull

# Stop services gracefully
echo "🛑 Stopping services..."
docker-compose down --remove-orphans

# Start all services
echo "🚀 Starting all services..."
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 30

echo ""
echo "✅ Deployment completed for ${ENVIRONMENT^^} environment!"
echo ""

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
docker-compose ps