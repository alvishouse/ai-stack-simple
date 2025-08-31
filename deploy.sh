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

# Install nginx if not present
if ! command -v nginx &> /dev/null; then
    echo "📦 Installing nginx..."
    apt update && apt install -y nginx
fi

# Copy nginx configuration
echo "⚙️ Setting up nginx..."
cp nginx/bionicvault.conf /etc/nginx/sites-available/
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
echo "✅ Deployment completed!"
echo ""
echo "🌐 Access your services:"
echo "• Flowise:    http://flowise.bionicvault.com"
echo "• n8n:        http://n8n.bionicvault.com" 
echo "• Open WebUI: http://openwebui.bionicvault.com"
echo "• LiteLLM:    http://litellm.bionicvault.com"
echo ""

docker-compose ps