# scripts/setup-server.sh
#!/bin/bash

# Install Docker and Docker Compose
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create project directory
mkdir -p /opt/ai-stack
cd /opt/ai-stack

# Clone repository
git clone https://github.com/yourusername/ai-stack.git .

# Create environment file (customize per server)
cp .env.example .env
nano .env  # Edit with server-specific values

# Make scripts executable
chmod +x scripts/*.sh

echo "✅ Server setup completed!"