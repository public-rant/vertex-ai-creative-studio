#!/bin/bash
set -e

# Deployment Status Checker for MCP Genmedia + Gemini CLI
# This script checks the status of all deployment components

echo "🔍 Checking MCP Genmedia + Gemini CLI deployment status..."

# Function to log messages with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to load environment variables
load_environment() {
    if [ -f .env ]; then
        export $(cat .env | grep -v '^#' | xargs)
    fi

    if [ -z "$PROJECT_ID" ]; then
        log "❌ PROJECT_ID not set. Please configure your environment."
        return 1
    fi

    if [ -z "$LOCATION" ]; then
        export LOCATION="us-central1"
    fi

    if [ -z "$GENMEDIA_BUCKET" ]; then
        export GENMEDIA_BUCKET="${PROJECT_ID}-genmedia"
    fi
}

# Function to check prerequisites
check_prerequisites() {
    log "📋 Checking prerequisites..."

    local missing_tools=()

    if ! command_exists gcloud; then
        missing_tools+=("gcloud")
    fi

    if ! command_exists docker; then
        missing_tools+=("docker")
    fi

    if ! command_exists curl; then
        missing_tools+=("curl")
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        log "❌ Missing tools: ${missing_tools[*]}"
        return 1
    fi

    log "✅ All required tools are available"
}

# Function to check Google Cloud authentication
check_gcloud_auth() {
    log "🔐 Checking Google Cloud authentication..."

    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
        log "❌ Not authenticated with Google Cloud"
        log "   Run: gcloud auth login"
        return 1
    fi

    local current_project
    current_project=$(gcloud config get-value project 2>/dev/null || echo "")

    if [ "$current_project" != "$PROJECT_ID" ]; then
        log "⚠️  Current project ($current_project) differs from configured PROJECT_ID ($PROJECT_ID)"
        log "   Run: gcloud config set project $PROJECT_ID"
    fi

    log "✅ Google Cloud authentication verified"
}

# Function to check Google Cloud APIs
check_apis() {
    log "🔌 Checking Google Cloud APIs..."

    local required_apis=(
        "cloudbuild.googleapis.com"
        "run.googleapis.com"
        "containerregistry.googleapis.com"
        "storage.googleapis.com"
        "aiplatform.googleapis.com"
        "secretmanager.googleapis.com"
    )

    local disabled_apis=()

    for api in "${required_apis[@]}"; do
        if ! gcloud services list --enabled --filter="name:$api" --format="value(name)" | grep -q "$api"; then
            disabled_apis+=("$api")
        fi
    done

    if [ ${#disabled_apis[@]} -ne 0 ]; then
        log "❌ Disabled APIs: ${disabled_apis[*]}"
        log "   Run: gcloud services enable ${disabled_apis[*]}"
        return 1
    fi

    log "✅ All required APIs are enabled"
}

# Function to check storage bucket
check_storage() {
    log "🪣 Checking storage bucket..."

    if ! gsutil ls "gs://$GENMEDIA_BUCKET" >/dev/null 2>&1; then
        log "❌ Storage bucket 'gs://$GENMEDIA_BUCKET' not found"
        log "   Run: gsutil mb -l $LOCATION gs://$GENMEDIA_BUCKET"
        return 1
    fi

    # Check bucket permissions
    if ! gsutil iam get "gs://$GENMEDIA_BUCKET" >/dev/null 2>&1; then
        log "⚠️  Cannot access bucket IAM policies"
    fi

    log "✅ Storage bucket exists and is accessible"
}

# Function to check secrets
check_secrets() {
    log "🔐 Checking Secret Manager secrets..."

    local secrets=("brave-api-key")
    local missing_secrets=()

    for secret in "${secrets[@]}"; do
        if ! gcloud secrets describe "$secret" >/dev/null 2>&1; then
            missing_secrets+=("$secret")
        fi
    done

    if [ ${#missing_secrets[@]} -ne 0 ]; then
        log "⚠️  Missing secrets: ${missing_secrets[*]}"
        log "   These secrets are optional but recommended"
    else
        log "✅ All secrets are configured"
    fi
}

# Function to check Cloud Run service
check_cloudrun() {
    log "🏃 Checking Cloud Run service..."

    local service_info
    service_info=$(gcloud run services describe mcp-genmedia \
        --region="$LOCATION" \
        --format="value(status.url,status.conditions[0].status)" 2>/dev/null || echo "")

    if [ -z "$service_info" ]; then
        log "❌ Cloud Run service 'mcp-genmedia' not found in region $LOCATION"
        log "   Deploy with: ./deploy-production.sh deploy"
        return 1
    fi

    local service_url service_status
    service_url=$(echo "$service_info" | cut -d' ' -f1)
    service_status=$(echo "$service_info" | cut -d' ' -f2)

    if [ "$service_status" != "True" ]; then
        log "❌ Cloud Run service is not ready (status: $service_status)"
        return 1
    fi

    log "✅ Cloud Run service is running"
    log "   URL: $service_url"

    # Test health endpoint
    if curl -sf "$service_url/health" >/dev/null 2>&1; then
        log "✅ Health check passed"
    else
        log "⚠️  Health check failed - service may be starting up"
    fi
}

# Function to check container images
check_images() {
    log "📦 Checking container images..."

    local images
    images=$(gcloud container images list --repository="gcr.io/$PROJECT_ID" --filter="name:mcp-genmedia" --format="value(name)" 2>/dev/null || echo "")

    if [ -z "$images" ]; then
        log "❌ No container images found for mcp-genmedia"
        log "   Build with: ./deploy-production.sh deploy"
        return 1
    fi

    local latest_image
    latest_image=$(gcloud container images list-tags "gcr.io/$PROJECT_ID/mcp-genmedia" \
        --format="value(tags)" --limit=1 2>/dev/null | head -n1)

    if [ -n "$latest_image" ]; then
        log "✅ Container images available (latest: $latest_image)"
    else
        log "⚠️  Container images found but no tags available"
    fi
}

# Function to check service accounts
check_service_accounts() {
    log "👤 Checking service accounts..."

    local required_sas=("cloudbuild" "mcp-genmedia-runner")
    local missing_sas=()

    for sa in "${required_sas[@]}"; do
        if ! gcloud iam service-accounts describe "${sa}@${PROJECT_ID}.iam.gserviceaccount.com" >/dev/null 2>&1; then
            missing_sas+=("$sa")
        fi
    done

    if [ ${#missing_sas[@]} -ne 0 ]; then
        log "❌ Missing service accounts: ${missing_sas[*]}"
        log "   Create with: ./deploy-terraform.sh deploy"
        return 1
    fi

    log "✅ All service accounts exist"
}

# Function to check local development environment
check_local_dev() {
    log "💻 Checking local development environment..."

    # Check if DevContainer exists
    if [ -d ".devcontainer" ]; then
        log "✅ DevContainer configuration found"
    else
        log "⚠️  DevContainer configuration not found"
    fi

    # Check if MCP config exists
    if [ -f "$HOME/.config/mcp/config.json" ]; then
        log "✅ MCP configuration found"
    else
        log "⚠️  MCP configuration not found at ~/.config/mcp/config.json"
    fi

    # Check if Python environment exists
    if [ -d "venv" ]; then
        log "✅ Python virtual environment found"
    else
        log "⚠️  Python virtual environment not found"
    fi

    # Check if Node.js dependencies are installed
    if [ -d "node_modules" ]; then
        log "✅ Node.js dependencies installed"
    else
        log "⚠️  Node.js dependencies not installed"
    fi
}

# Function to check Terraform state
check_terraform() {
    log "🏗️  Checking Terraform state..."

    if [ ! -f "deployment/terraform/terraform.tfstate" ]; then
        log "⚠️  Terraform state not found - infrastructure may not be managed by Terraform"
        return 0
    fi

    if command_exists terraform; then
        cd deployment/terraform
        if terraform state list >/dev/null 2>&1; then
            local resource_count
            resource_count=$(terraform state list | wc -l)
            log "✅ Terraform state is valid ($resource_count resources)"
        else
            log "❌ Terraform state is invalid or corrupted"
            cd ../..
            return 1
        fi
        cd ../..
    else
        log "⚠️  Terraform not installed - cannot validate state"
    fi
}

# Function to generate deployment report
generate_report() {
    log "📊 Generating deployment report..."

    local report_file="deployment-status-$(date +%Y%m%d_%H%M%S).txt"

    cat > "$report_file" << EOF
MCP Genmedia + Gemini CLI Deployment Status Report
Generated: $(date)
Project ID: $PROJECT_ID
Region: $LOCATION
Bucket: $GENMEDIA_BUCKET

=== System Status ===
EOF

    # Add service status to report
    if gcloud run services describe mcp-genmedia --region="$LOCATION" --format="value(status.url)" >/dev/null 2>&1; then
        local service_url
        service_url=$(gcloud run services describe mcp-genmedia --region="$LOCATION" --format="value(status.url)")
        echo "Cloud Run Service: RUNNING ($service_url)" >> "$report_file"
    else
        echo "Cloud Run Service: NOT DEPLOYED" >> "$report_file"
    fi

    # Add bucket status
    if gsutil ls "gs://$GENMEDIA_BUCKET" >/dev/null 2>&1; then
        echo "Storage Bucket: EXISTS" >> "$report_file"
    else
        echo "Storage Bucket: NOT FOUND" >> "$report_file"
    fi

    # Add API status
    echo "" >> "$report_file"
    echo "=== Enabled APIs ===" >> "$report_file"
    gcloud services list --enabled --filter="name:*.googleapis.com" --format="value(name)" | grep -E "(cloudbuild|run|storage|aiplatform|secretmanager)" >> "$report_file"

    log "✅ Report saved to: $report_file"
}

# Function to show recommendations
show_recommendations() {
    log "💡 Deployment recommendations..."

    echo ""
    echo "📋 Next Steps:"

    # Check if service is running
    if ! gcloud run services describe mcp-genmedia --region="$LOCATION" >/dev/null 2>&1; then
        echo "  1. Deploy the service: ./deploy-production.sh deploy"
    fi

    # Check if Terraform is set up
    if [ ! -f "deployment/terraform/terraform.tfvars" ]; then
        echo "  2. Configure Terraform: cp deployment/terraform/terraform.tfvars.example deployment/terraform/terraform.tfvars"
    fi

    # Check if local development is set up
    if [ ! -d "venv" ]; then
        echo "  3. Set up local development: ./local-setup.sh"
    fi

    echo ""
    echo "🔧 Useful Commands:"
    echo "  ./deploy-production.sh info     # Show deployment information"
    echo "  ./deploy-terraform.sh output    # Show Terraform outputs"
    echo "  ./start-dev.sh                  # Start local development"
    echo "  ./test-mcp-connectivity.sh      # Test MCP servers"

    echo ""
    echo "📚 Documentation:"
    echo "  DEPLOYMENT_README.md            # Complete deployment guide"
    echo "  CONTAINER_DEPLOYMENT_PLAN.md    # Architecture overview"
    echo "  .env.example                    # Environment configuration"
}

# Function to run all checks
run_all_checks() {
    local failed_checks=()

    check_prerequisites || failed_checks+=("prerequisites")
    load_environment || failed_checks+=("environment")
    check_gcloud_auth || failed_checks+=("authentication")
    check_apis || failed_checks+=("apis")
    check_storage || failed_checks+=("storage")
    check_secrets || failed_checks+=("secrets")
    check_service_accounts || failed_checks+=("service-accounts")
    check_cloudrun || failed_checks+=("cloudrun")
    check_images || failed_checks+=("images")
    check_terraform || failed_checks+=("terraform")
    check_local_dev || failed_checks+=("local-dev")

    echo ""
    echo "=============================================="
    if [ ${#failed_checks[@]} -eq 0 ]; then
        log "✅ All checks passed! Deployment is healthy."
    else
        log "⚠️  Some checks failed: ${failed_checks[*]}"
        log "   Review the output above for details."
    fi
    echo "=============================================="

    return ${#failed_checks[@]}
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [COMMAND]

Commands:
  all           Run all deployment checks (default)
  auth          Check Google Cloud authentication
  apis          Check enabled APIs
  storage       Check storage bucket
  secrets       Check Secret Manager secrets
  cloudrun      Check Cloud Run service
  images        Check container images
  terraform     Check Terraform state
  local         Check local development environment
  report        Generate deployment status report
  help          Show this help message

Examples:
  $0                # Run all checks
  $0 cloudrun       # Check only Cloud Run service
  $0 report         # Generate status report

Environment Variables:
  PROJECT_ID        Google Cloud project ID (required)
  LOCATION          Deployment region (default: us-central1)
  GENMEDIA_BUCKET   Storage bucket name (default: {PROJECT_ID}-genmedia)

EOF
}

# Main function
main() {
    local command="${1:-all}"

    case "$command" in
        "all")
            run_all_checks
            local exit_code=$?
            generate_report
            show_recommendations
            exit $exit_code
            ;;
        "auth")
            load_environment && check_gcloud_auth
            ;;
        "apis")
            load_environment && check_apis
            ;;
        "storage")
            load_environment && check_storage
            ;;
        "secrets")
            load_environment && check_secrets
            ;;
        "cloudrun")
            load_environment && check_cloudrun
            ;;
        "images")
            load_environment && check_images
            ;;
        "terraform")
            check_terraform
            ;;
        "local")
            check_local_dev
            ;;
        "report")
            load_environment && generate_report
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            log "❌ Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Ensure we're in the right directory
if [ ! -f "CONTAINER_DEPLOYMENT_PLAN.md" ]; then
    log "❌ This script must be run from the mcp-genmedia directory"
    exit 1
fi

# Run main function
main "$@"
