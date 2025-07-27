#!/bin/bash
set -e

# Production entrypoint script for MCP Genmedia + Gemini CLI

# Function to log messages with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if required environment variables are set
check_env() {
    local required_vars=("PROJECT_ID" "LOCATION" "GENMEDIA_BUCKET")
    local missing_vars=()

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -ne 0 ]; then
        log "ERROR: Missing required environment variables: ${missing_vars[*]}"
        log "Please set the following environment variables:"
        for var in "${missing_vars[@]}"; do
            log "  - $var"
        done
        exit 1
    fi
}

# Function to wait for Google Cloud authentication
wait_for_auth() {
    log "Checking Google Cloud authentication..."
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
            log "Google Cloud authentication verified"
            return 0
        fi

        log "Waiting for Google Cloud authentication... (attempt $attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done

    log "ERROR: Google Cloud authentication not found after $max_attempts attempts"
    log "Please ensure the service account key is properly mounted or authentication is configured"
    exit 1
}

# Function to configure Google Cloud project
configure_gcloud() {
    log "Configuring Google Cloud project..."
    gcloud config set project "$PROJECT_ID"
    gcloud config set compute/zone "$LOCATION"

    # Verify project access
    if ! gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1; then
        log "ERROR: Cannot access project $PROJECT_ID. Please check permissions."
        exit 1
    fi

    log "Google Cloud project configured successfully"
}

# Function to start MCP servers
start_mcp_servers() {
    log "Starting MCP servers..."

    # Start filesystem server
    log "Starting filesystem MCP server..."
    npx @modelcontextprotocol/server-filesystem /home/app &
    local fs_pid=$!
    echo $fs_pid > /tmp/mcp-filesystem.pid

    # Start memory server
    log "Starting memory MCP server..."
    npx @modelcontextprotocol/server-memory &
    local memory_pid=$!
    echo $memory_pid > /tmp/mcp-memory.pid

    # Start brave search server if API key is available
    if [ -n "$BRAVE_API_KEY" ]; then
        log "Starting Brave Search MCP server..."
        BRAVE_API_KEY="$BRAVE_API_KEY" npx @modelcontextprotocol/server-brave-search &
        local brave_pid=$!
        echo $brave_pid > /tmp/mcp-brave.pid
    else
        log "Brave Search API key not provided, skipping Brave Search server"
    fi

    # Start genmedia server
    if [ -f "/home/app/bin/mcp-genmedia-server" ]; then
        log "Starting Genmedia MCP server..."
        PROJECT_ID="$PROJECT_ID" LOCATION="$LOCATION" GENMEDIA_BUCKET="$GENMEDIA_BUCKET" \
            /home/app/bin/mcp-genmedia-server &
        local genmedia_pid=$!
        echo $genmedia_pid > /tmp/mcp-genmedia.pid
    else
        log "Genmedia server binary not found, skipping"
    fi

    # Wait a moment for servers to start
    sleep 3
    log "MCP servers started successfully"
}

# Function to stop MCP servers
stop_mcp_servers() {
    log "Stopping MCP servers..."

    # Stop all MCP server processes
    for pidfile in /tmp/mcp-*.pid; do
        if [ -f "$pidfile" ]; then
            local pid=$(cat "$pidfile")
            if kill -0 "$pid" 2>/dev/null; then
                log "Stopping process $pid"
                kill "$pid"
            fi
            rm -f "$pidfile"
        fi
    done

    # Force kill any remaining MCP processes
    pkill -f "mcp-" || true

    log "MCP servers stopped"
}

# Function to start health check server
start_health_server() {
    log "Starting health check server..."

    # Create a simple health check endpoint
    cat > /tmp/health_server.py << 'EOF'
import http.server
import socketserver
import json
import subprocess
import os
from urllib.parse import urlparse

class HealthHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            try:
                # Check if MCP servers are running
                health_status = {
                    "status": "healthy",
                    "timestamp": subprocess.check_output(['date', '-Iseconds']).decode().strip(),
                    "services": {}
                }

                # Check individual MCP servers
                for service in ['filesystem', 'memory', 'brave', 'genmedia']:
                    pidfile = f'/tmp/mcp-{service}.pid'
                    if os.path.exists(pidfile):
                        with open(pidfile, 'r') as f:
                            pid = int(f.read().strip())
                        try:
                            os.kill(pid, 0)  # Check if process exists
                            health_status["services"][service] = "running"
                        except OSError:
                            health_status["services"][service] = "stopped"
                    else:
                        health_status["services"][service] = "not_started"

                # Check Google Cloud authentication
                try:
                    subprocess.check_output(['gcloud', 'auth', 'list', '--filter=status:ACTIVE'],
                                          stderr=subprocess.DEVNULL)
                    health_status["gcloud_auth"] = "authenticated"
                except subprocess.CalledProcessError:
                    health_status["gcloud_auth"] = "not_authenticated"
                    health_status["status"] = "degraded"

                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(health_status, indent=2).encode())

            except Exception as e:
                error_response = {
                    "status": "unhealthy",
                    "error": str(e),
                    "timestamp": subprocess.check_output(['date', '-Iseconds']).decode().strip()
                }
                self.send_response(500)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(error_response, indent=2).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass  # Suppress default logging

if __name__ == "__main__":
    PORT = 8080
    with socketserver.TCPServer(("", PORT), HealthHandler) as httpd:
        httpd.serve_forever()
EOF

    python3 /tmp/health_server.py &
    local health_pid=$!
    echo $health_pid > /tmp/health-server.pid

    log "Health check server started on port 8080"
}

# Function to stop health check server
stop_health_server() {
    if [ -f "/tmp/health-server.pid" ]; then
        local pid=$(cat "/tmp/health-server.pid")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
        fi
        rm -f "/tmp/health-server.pid"
    fi
}

# Function to handle shutdown signals
shutdown_handler() {
    log "Received shutdown signal, cleaning up..."
    stop_health_server
    stop_mcp_servers
    log "Shutdown complete"
    exit 0
}

# Function to run development mode
run_dev() {
    log "Starting in development mode..."
    check_env
    configure_gcloud
    start_mcp_servers
    start_health_server

    log "Development environment ready!"
    log "Health check available at http://localhost:8080/health"
    log "MCP servers are running in the background"

    # Keep the container running
    tail -f /dev/null
}

# Function to run production serve mode
run_serve() {
    log "Starting in production serve mode..."
    check_env
    wait_for_auth
    configure_gcloud
    start_mcp_servers
    start_health_server

    log "Production environment ready!"
    log "Health check available at http://localhost:8080/health"
    log "All services are running"

    # Keep the container running and monitor services
    while true; do
        # Check if health server is still running
        if ! kill -0 $(cat /tmp/health-server.pid 2>/dev/null) 2>/dev/null; then
            log "Health server died, restarting..."
            start_health_server
        fi

        # Check MCP servers
        for service in filesystem memory genmedia; do
            pidfile="/tmp/mcp-${service}.pid"
            if [ -f "$pidfile" ]; then
                pid=$(cat "$pidfile")
                if ! kill -0 "$pid" 2>/dev/null; then
                    log "MCP $service server died, container needs restart"
                    exit 1
                fi
            fi
        done

        sleep 30
    done
}

# Function to run tests
run_test() {
    log "Running tests..."
    check_env
    configure_gcloud

    # Test Google Cloud connectivity
    log "Testing Google Cloud connectivity..."
    if gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1; then
        log "✓ Google Cloud connectivity test passed"
    else
        log "✗ Google Cloud connectivity test failed"
        exit 1
    fi

    # Test bucket access
    log "Testing bucket access..."
    if gsutil ls "gs://$GENMEDIA_BUCKET" >/dev/null 2>&1; then
        log "✓ Bucket access test passed"
    else
        log "✗ Bucket access test failed"
        exit 1
    fi

    log "All tests passed!"
}

# Set up signal handlers
trap shutdown_handler SIGTERM SIGINT

# Main execution
case "${1:-serve}" in
    "serve")
        run_serve
        ;;
    "dev")
        run_dev
        ;;
    "test")
        run_test
        ;;
    "bash")
        log "Starting interactive bash session..."
        exec /bin/bash
        ;;
    *)
        log "Usage: $0 {serve|dev|test|bash}"
        log "  serve - Run in production mode (default)"
        log "  dev   - Run in development mode"
        log "  test  - Run connectivity tests"
        log "  bash  - Start interactive bash session"
        exit 1
        ;;
esac
