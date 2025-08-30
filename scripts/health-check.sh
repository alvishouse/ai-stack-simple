#!/bin/bash
# scripts/health-check.sh

set -e

source .env

echo "🏥 Running health checks..."

# Check PostgreSQL
echo "Checking PostgreSQL..."
if docker-compose exec -T postgres pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}; then
    echo "✅ PostgreSQL is healthy"
else
    echo "❌ PostgreSQL is not responding"
    exit 1
fi

# Check Redis
echo "Checking Redis..."
if docker-compose exec -T redis redis-cli ping; then
    echo "✅ Redis is healthy"
else
    echo "❌ Redis is not responding"
    exit 1
fi

# Check web services
services=("langfuse:3005" "flowise:3001" "n8n:5678")

for service in "${services[@]}"; do
    name=${service%:*}
    port=${service#*:}
    echo "Checking $name..."
    if curl -f -s -o /dev/null "http://localhost:$port"; then
        echo "✅ $name is healthy"
    else
        echo "❌ $name is not responding"
    fi
done

echo "🎉 All health checks completed!"