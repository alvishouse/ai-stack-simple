# Simple AI Stack

Lightweight deployment with 4 core services:
- n8n (Workflow automation)
- Flowise (AI workflow builder) 
- Open WebUI (AI chat interface)
- LiteLLM (Unified LLM proxy)

## Quick Start

1. Copy `.env.example` to `.env`
2. Set your API keys and passwords
3. Run: `./deploy.sh`

## Service URLs

- n8n: http://your-server:5678
- Flowise: http://your-server:3001
- Open WebUI: http://your-server:8080
- LiteLLM: http://your-server:4000

## Deployment

- Push to main → Auto-deploy to dev
- Manual workflow → Deploy to prod