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

# Check service health
echo "🏥 Checking service health..."

services=("n8n:5678" "flowise:3001" "openwebui:8080" "litellm:4000")

for service in "${services[@]}"; do
    name=${service%:*}
    port=${service#*:}
    echo "Checking $name..."
    if curl -f -s -o /dev/null --max-time 10 "http://localhost:$port" || curl -f -s -o /dev/null --max-time 10 "http://localhost:$port/health"; then
        echo "✅ $name is healthy"
    else
        echo "⚠️ $name may still be starting up"
    fi
done

echo ""
echo "✅ Deployment completed!"
echo ""
echo "🌐 Access your services:"
echo "• n8n:        http://${SERVER_IP}:5678"
echo "• Flowise:    http://${SERVER_IP}:3001"  
echo "• Open WebUI: http://${SERVER_IP}:8080"
echo "• LiteLLM:    http://${SERVER_IP}:4000"
echo ""

docker-compose ps