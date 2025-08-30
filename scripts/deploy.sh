#!/bin/bash
# scripts/deploy.sh

set -e

echo "🚀 Starting AI Stack deployment..."

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

# Start database first
echo "🗄️ Starting database..."
docker-compose up -d postgres redis
sleep 30

# Start application services
echo "🚀 Starting application services..."
docker-compose up -d langfuse flowise n8n

# Wait for services to be healthy
echo "⏳ Waiting for services to be ready..."
sleep 45

# Check service health
echo "🏥 Checking service health..."
./scripts/health-check.sh

echo "✅ Deployment completed successfully!"
docker-compose ps