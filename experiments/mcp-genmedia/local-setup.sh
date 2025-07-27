#!/bin/bash
set -e

# Local Development Setup Script for MCP Genmedia + Gemini CLI
# This script sets up the local development environment

echo "🚀 Setting up MCP Genmedia + Gemini CLI local development environment..."

# Function to log messages with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check system requirements
check_requirements() {
    log "Checking system requirements..."

    local missing_deps=()

    # Check for Docker
    if ! command_exists docker; then
        missing_deps+=("docker")
    fi

    # Check for Docker Compose
    if ! command_exists docker-compose; then
        missing_deps+=("docker-compose")
    fi

    # Check for VS Code (optional but recommended)
    if ! command_exists code; then
        log "⚠️  VS Code not found. DevContainer support will be limited."
    fi

    # Check for Node.js
    if ! command_exists node; then
        missing_deps+=("node")
    fi

    # Check for Python
    if ! command_exists python3; then
        missing_deps+=("python3")
    fi

    # Check for Go
    if ! command_exists go; then
        missing_deps+=("go")
    fi

    # Check for gcloud CLI
    if ! command_exists gcloud; then
        missing_deps+=("gcloud")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        log "❌ Missing required dependencies: ${missing_deps[*]}"
        log "Please install the missing dependencies and run this script again."
        log ""
        log "Installation instructions:"
        for dep in "${missing_deps[@]}"; do
            case $dep in
                docker)
                    log "  - Docker: https://docs.docker.com/get-docker/"
                    ;;
                docker-compose)
                    log "  - Docker Compose: https://docs.docker.com/compose/install/"
                    ;;
                node)
                    log "  - Node.js: https://nodejs.org/en/download/"
                    ;;
                python3)
                    log "  - Python 3: https://www.python.org/downloads/"
                    ;;
                go)
                    log "  - Go: https://golang.org/doc/install"
                    ;;
                gcloud)
                    log "  - Google Cloud CLI: https://cloud.google.com/sdk/docs/install"
                    ;;
            esac
        done
        exit 1
    fi

    log "✅ All required dependencies are installed"
}

# Function to create environment file
create_env_file() {
    log "Creating environment configuration..."

    if [ ! -f .env ]; then
        cat > .env << 'EOF'
# Google Cloud Configuration
PROJECT_ID=your-project-id
LOCATION=us-central1
GENMEDIA_BUCKET=your-project-id-genmedia

# Optional: Brave Search API Key
BRAVE_API_KEY=

# Development Configuration
NODE_ENV=development
LOG_LEVEL=debug

# MCP Server Configuration
MCP_CONFIG_PATH=~/.config/mcp/config.json
EOF
        log "📝 Created .env file - please update with your values"
        log "⚠️  Don't forget to set your PROJECT_ID and other variables in .env"
    else
        log "✅ .env file already exists"
    fi
}

# Function to set up Python virtual environment
setup_python_env() {
    log "Setting up Python virtual environment..."

    if [ ! -d "venv" ]; then
        python3 -m venv venv
        log "✅ Python virtual environment created"
    fi

    source venv/bin/activate
    pip install --upgrade pip setuptools wheel

    # Install Python dependencies
    log "Installing Python dependencies..."
    pip install google-cloud-aiplatform google-auth google-auth-oauthlib google-cloud-storage google-generativeai

    log "✅ Python environment setup complete"
}

# Function to set up Node.js dependencies
setup_node_env() {
    log "Setting up Node.js environment..."

    # Install global MCP packages
    log "Installing global MCP packages..."
    npm install -g @modelcontextprotocol/server-filesystem
    npm install -g @modelcontextprotocol/server-memory
    npm install -g @modelcontextprotocol/server-brave-search
    npm install -g @modelcontextprotocol/inspector

    # Create package.json if it doesn't exist
    if [ ! -f package.json ]; then
        cat > package.json << 'EOF'
{
  "name": "mcp-genmedia",
  "version": "1.0.0",
  "description": "MCP Genmedia + Gemini CLI integration",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js",
    "test": "jest",
    "mcp:start": "./start-mcp-servers.sh",
    "mcp:test": "./test-mcp-connectivity.sh"
  },
  "keywords": ["mcp", "gemini", "vertex-ai", "genmedia"],
  "author": "",
  "license": "MIT",
  "devDependencies": {
    "nodemon": "^3.0.0",
    "jest": "^29.0.0"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "latest"
  }
}
EOF
        log "📝 Created package.json"
    fi

    # Install local dependencies
    if [ -f package.json ]; then
        npm install
        log "✅ Node.js dependencies installed"
    fi
}

# Function to build Go MCP server
setup_go_env() {
    log "Setting up Go environment..."

    if [ -d "mcp-genmedia-go" ]; then
        cd mcp-genmedia-go
        log "Building Go MCP server..."
        go mod tidy
        go build -o ../bin/mcp-genmedia-server .
        cd ..
        log "✅ Go MCP server built successfully"
    else
        log "⚠️  Go MCP server source not found, skipping Go build"
    fi
}

# Function to create MCP configuration
setup_mcp_config() {
    log "Setting up MCP configuration..."

    mkdir -p ~/.config/mcp

    # Create MCP configuration
    cat > ~/.config/mcp/config.json << 'EOF'
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-filesystem", "."]
    },
    "memory": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-memory"]
    },
    "brave-search": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-brave-search"],
      "env": {
        "BRAVE_API_KEY": ""
      }
    },
    "genmedia": {
      "command": "./bin/mcp-genmedia-server",
      "args": [],
      "env": {
        "PROJECT_ID": "",
        "LOCATION": "us-central1",
        "GENMEDIA_BUCKET": ""
      }
    }
  }
}
EOF

    log "✅ MCP configuration created at ~/.config/mcp/config.json"
}

# Function to create development scripts
create_dev_scripts() {
    log "Creating development scripts..."

    # Create bin directory
    mkdir -p bin

    # Create start script
    cat > start-dev.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Starting MCP Genmedia development environment..."

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Activate Python virtual environment
if [ -d "venv" ]; then
    source venv/bin/activate
    echo "✅ Python virtual environment activated"
fi

# Start MCP servers
echo "Starting MCP servers..."
./start-mcp-servers.sh &

# Wait a moment for servers to start
sleep 3

echo "✅ Development environment ready!"
echo "📍 MCP servers are running in the background"
echo "🔍 Use 'mcp-inspector' to debug MCP servers"
echo "🧪 Run './test-mcp-connectivity.sh' to test connections"
echo "🛑 Use 'pkill -f mcp' to stop all MCP servers"
EOF

    chmod +x start-dev.sh

    # Create test script
    cat > run-tests.sh << 'EOF'
#!/bin/bash
set -e

echo "🧪 Running MCP Genmedia tests..."

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Activate Python virtual environment
if [ -d "venv" ]; then
    source venv/bin/activate
fi

# Run connectivity tests
if [ -f "test-mcp-connectivity.sh" ]; then
    ./test-mcp-connectivity.sh
fi

# Run Python tests
if [ -f "test-gemini-mcp.py" ]; then
    python3 test-gemini-mcp.py
fi

# Run Node.js tests
if [ -f "package.json" ] && grep -q '"test"' package.json; then
    npm test
fi

echo "✅ All tests completed!"
EOF

    chmod +x run-tests.sh

    log "✅ Development scripts created"
}

# Function to set up DevContainer
setup_devcontainer() {
    log "Setting up DevContainer configuration..."

    if command_exists code && [ -d ".devcontainer" ]; then
        log "✅ DevContainer configuration found"
        log "💡 You can use 'code .' and reopen in container for full DevContainer experience"
    else
        log "⚠️  DevContainer configuration not found or VS Code not installed"
    fi
}

# Function to verify Google Cloud setup
verify_gcloud_setup() {
    log "Verifying Google Cloud setup..."

    # Check if gcloud is authenticated
    if gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
        log "✅ Google Cloud authentication verified"

        # Get current project
        current_project=$(gcloud config get-value project 2>/dev/null || echo "")
        if [ -n "$current_project" ]; then
            log "📍 Current project: $current_project"
        else
            log "⚠️  No default project set. Use 'gcloud config set project PROJECT_ID'"
        fi
    else
        log "⚠️  Google Cloud not authenticated. Run 'gcloud auth login' and 'gcloud auth application-default login'"
    fi
}

# Function to create Docker Compose for local development
create_docker_compose() {
    log "Creating Docker Compose configuration for local development..."

    cat > docker-compose.dev.yml << 'EOF'
version: '3.8'

services:
  mcp-genmedia:
    build:
      context: .
      dockerfile: .devcontainer/Dockerfile
    ports:
      - "8080:8080"
    volumes:
      - .:/workspace:cached
      - ~/.config/gcloud:/home/vscode/.config/gcloud:ro
    environment:
      - PROJECT_ID=${PROJECT_ID}
      - LOCATION=${LOCATION:-us-central1}
      - GENMEDIA_BUCKET=${GENMEDIA_BUCKET}
      - BRAVE_API_KEY=${BRAVE_API_KEY}
    command: dev
    depends_on:
      - redis
    networks:
      - mcp-network

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    networks:
      - mcp-network

  # Optional: PostgreSQL for persistent storage
  postgres:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=mcp_genmedia
      - POSTGRES_USER=mcp_user
      - POSTGRES_PASSWORD=mcp_password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - mcp-network

volumes:
  redis_data:
  postgres_data:

networks:
  mcp-network:
    driver: bridge
EOF

    log "✅ Docker Compose configuration created"
}

# Main setup function
main() {
    echo "=============================================="
    echo "🚀 MCP Genmedia + Gemini CLI Setup"
    echo "=============================================="

    check_requirements
    create_env_file
    setup_python_env
    setup_node_env
    setup_go_env
    setup_mcp_config
    create_dev_scripts
    setup_devcontainer
    create_docker_compose
    verify_gcloud_setup

    echo ""
    echo "=============================================="
    echo "✅ Setup Complete!"
    echo "=============================================="
    echo ""
    echo "Next steps:"
    echo "1. 📝 Edit .env file with your project settings"
    echo "2. 🔐 Authenticate with Google Cloud:"
    echo "   gcloud auth login"
    echo "   gcloud auth application-default login"
    echo "3. 🚀 Start development environment:"
    echo "   ./start-dev.sh"
    echo "4. 🧪 Run tests:"
    echo "   ./run-tests.sh"
    echo "5. 🐳 Or use Docker Compose:"
    echo "   docker-compose -f docker-compose.dev.yml up"
    echo ""
    echo "📚 Additional resources:"
    echo "- DevContainer: Open in VS Code and reopen in container"
    echo "- MCP Inspector: Run 'mcp-inspector' for debugging"
    echo "- Health check: Visit http://localhost:8080/health"
    echo ""
    echo "🎉 Happy coding!"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
