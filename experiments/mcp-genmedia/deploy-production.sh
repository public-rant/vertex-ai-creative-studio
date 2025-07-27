#!/bin/bash
set -e

# Production Deployment Script for MCP Genmedia + Gemini CLI
# This script deploys the application to Google Cloud using Cloud Build

echo "🚀 Deploying MCP Genmedia + Gemini CLI to production..."

# Function to log messages with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check requirements
check_requirements() {
    log "Checking deployment requirements..."

    if ! command_exists gcloud; then
        log "❌ Google Cloud CLI not found. Please install: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi

    if ! command_exists docker; then
        log "❌ Docker not found. Please install: https://docs.docker.com/get-docker/"
        exit 1
    fi

    # Check if authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
        log "❌ Not authenticated with Google Cloud. Run 'gcloud auth login'"
        exit 1
    fi

    log "✅ All requirements met"
}

# Function to load environment variables
load_environment() {
    log "Loading environment configuration..."

    # Load from .env file if it exists
    if [ -f .env ]; then
        export $(cat .env | grep -v '^#' | xargs)
        log "✅ Loaded environment from .env file"
    fi

    # Check required environment variables
    if [ -z "$PROJECT_ID" ]; then
        log "❌ PROJECT_ID not set. Please set in .env or environment"
        exit 1
    fi

    if [ -z "$LOCATION" ]; then
        export LOCATION="us-central1"
        log "⚠️  LOCATION not set, using default: us-central1"
    fi

    if [ -z "$GENMEDIA_BUCKET" ]; then
        export GENMEDIA_BUCKET="${PROJECT_ID}-genmedia"
        log "⚠️  GENMEDIA_BUCKET not set, using default: ${GENMEDIA_BUCKET}"
    fi

    log "📍 Project ID: $PROJECT_ID"
    log "📍 Location: $LOCATION"
    log "📍 Bucket: $GENMEDIA_BUCKET"
}

# Function to set up Google Cloud project
setup_gcloud_project() {
    log "Setting up Google Cloud project..."

    # Set the project
    gcloud config set project "$PROJECT_ID"

    # Verify project access
    if ! gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1; then
        log "❌ Cannot access project $PROJECT_ID. Please check permissions."
        exit 1
    fi

    log "✅ Google Cloud project configured"
}

# Function to enable required APIs
enable_apis() {
    log "Enabling required Google Cloud APIs..."

    local apis=(
        "cloudbuild.googleapis.com"
        "run.googleapis.com"
        "containerregistry.googleapis.com"
        "artifactregistry.googleapis.com"
        "storage.googleapis.com"
        "aiplatform.googleapis.com"
        "secretmanager.googleapis.com"
    )

    for api in "${apis[@]}"; do
        log "Enabling $api..."
        gcloud services enable "$api" --quiet
    done

    log "✅ APIs enabled successfully"
}

# Function to create storage bucket if it doesn't exist
create_bucket() {
    log "Checking storage bucket..."

    if ! gsutil ls "gs://$GENMEDIA_BUCKET" >/dev/null 2>&1; then
        log "Creating storage bucket: $GENMEDIA_BUCKET"
        gsutil mb -l "$LOCATION" "gs://$GENMEDIA_BUCKET"

        # Set bucket permissions
        gsutil iam ch allUsers:objectViewer "gs://$GENMEDIA_BUCKET" || true

        log "✅ Storage bucket created"
    else
        log "✅ Storage bucket already exists"
    fi
}

# Function to create or update secrets
setup_secrets() {
    log "Setting up Secret Manager secrets..."

    # Create Brave API key secret if it doesn't exist
    if ! gcloud secrets describe brave-api-key >/dev/null 2>&1; then
        log "Creating brave-api-key secret..."
        echo "${BRAVE_API_KEY:-}" | gcloud secrets create brave-api-key --data-file=-
        log "✅ brave-api-key secret created"
    else
        # Update if BRAVE_API_KEY is provided
        if [ -n "$BRAVE_API_KEY" ]; then
            log "Updating brave-api-key secret..."
            echo "$BRAVE_API_KEY" | gcloud secrets versions add brave-api-key --data-file=-
            log "✅ brave-api-key secret updated"
        else
            log "✅ brave-api-key secret exists (not updating)"
        fi
    fi
}

# Function to deploy using Cloud Build
deploy_with_cloudbuild() {
    log "Starting Cloud Build deployment..."

    # Submit build to Cloud Build
    gcloud builds submit \
        --config=deployment/cloudbuild.yaml \
        --substitutions=_REGION="$LOCATION",_GENMEDIA_BUCKET="$GENMEDIA_BUCKET" \
        --timeout=1200s \
        .

    log "✅ Cloud Build deployment completed"
}

# Function to verify deployment
verify_deployment() {
    log "Verifying deployment..."

    # Get Cloud Run service URL
    local service_url
    service_url=$(gcloud run services describe mcp-genmedia \
        --region="$LOCATION" \
        --format="value(status.url)" 2>/dev/null || echo "")

    if [ -n "$service_url" ]; then
        log "✅ Service deployed successfully"
        log "🌐 Service URL: $service_url"

        # Test health endpoint
        log "Testing health endpoint..."
        if curl -sf "$service_url/health" >/dev/null; then
            log "✅ Health check passed"
        else
            log "⚠️  Health check failed - service may still be starting"
        fi
    else
        log "❌ Service deployment verification failed"
        exit 1
    fi
}

# Function to show deployment information
show_deployment_info() {
    log "📋 Deployment Information:"
    echo ""

    # Service URL
    local service_url
    service_url=$(gcloud run services describe mcp-genmedia \
        --region="$LOCATION" \
        --format="value(status.url)" 2>/dev/null || echo "Not found")

    echo "🌐 Service URL: $service_url"
    echo "📍 Region: $LOCATION"
    echo "🪣 Storage Bucket: gs://$GENMEDIA_BUCKET"
    echo "🔍 Health Check: $service_url/health"
    echo ""

    # Service status
    echo "📊 Service Status:"
    gcloud run services describe mcp-genmedia \
        --region="$LOCATION" \
        --format="table(metadata.name,status.conditions[0].type:label=READY,status.conditions[0].status,status.url:label=URL)" \
        2>/dev/null || echo "Service not found"

    echo ""
    echo "📚 Additional Commands:"
    echo "  View logs: gcloud logs tail /projects/$PROJECT_ID/logs/run.googleapis.com%2Fstdout --format='value(textPayload)'"
    echo "  Update service: gcloud run deploy mcp-genmedia --source . --region $LOCATION"
    echo "  Delete service: gcloud run services delete mcp-genmedia --region $LOCATION"
}

# Function to handle deployment rollback
rollback_deployment() {
    log "⏪ Rolling back deployment..."

    # Get previous revision
    local previous_revision
    previous_revision=$(gcloud run revisions list \
        --service=mcp-genmedia \
        --region="$LOCATION" \
        --format="value(metadata.name)" \
        --limit=2 \
        --sort-by="~metadata.creationTimestamp" | tail -n 1)

    if [ -n "$previous_revision" ]; then
        log "Rolling back to revision: $previous_revision"
        gcloud run services update-traffic mcp-genmedia \
            --to-revisions="$previous_revision=100" \
            --region="$LOCATION"
        log "✅ Rollback completed"
    else
        log "❌ No previous revision found for rollback"
        exit 1
    fi
}

# Function to clean up old revisions
cleanup_old_revisions() {
    log "🧹 Cleaning up old revisions..."

    # Keep only the latest 5 revisions
    local old_revisions
    old_revisions=$(gcloud run revisions list \
        --service=mcp-genmedia \
        --region="$LOCATION" \
        --format="value(metadata.name)" \
        --sort-by="~metadata.creationTimestamp" \
        --limit=100 | tail -n +6)

    if [ -n "$old_revisions" ]; then
        echo "$old_revisions" | while read -r revision; do
            log "Deleting revision: $revision"
            gcloud run revisions delete "$revision" --region="$LOCATION" --quiet
        done
        log "✅ Old revisions cleaned up"
    else
        log "ℹ️  No old revisions to clean up"
    fi
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [COMMAND]

Commands:
  deploy     Deploy the application (default)
  rollback   Rollback to previous revision
  cleanup    Clean up old revisions
  info       Show deployment information
  help       Show this help message

Environment Variables:
  PROJECT_ID        Google Cloud project ID (required)
  LOCATION          Deployment region (default: us-central1)
  GENMEDIA_BUCKET   Storage bucket name (default: {PROJECT_ID}-genmedia)
  BRAVE_API_KEY     Brave Search API key (optional)

Examples:
  $0                 # Deploy using default settings
  $0 deploy          # Same as above
  $0 rollback        # Rollback to previous version
  $0 cleanup         # Clean up old revisions
  $0 info            # Show deployment information

EOF
}

# Main function
main() {
    local command="${1:-deploy}"

    case "$command" in
        "deploy")
            check_requirements
            load_environment
            setup_gcloud_project
            enable_apis
            create_bucket
            setup_secrets
            deploy_with_cloudbuild
            verify_deployment
            show_deployment_info
            ;;
        "rollback")
            check_requirements
            load_environment
            setup_gcloud_project
            rollback_deployment
            show_deployment_info
            ;;
        "cleanup")
            check_requirements
            load_environment
            setup_gcloud_project
            cleanup_old_revisions
            ;;
        "info")
            check_requirements
            load_environment
            setup_gcloud_project
            show_deployment_info
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

# Handle script interruption
trap 'log "⚠️  Deployment interrupted"; exit 1' INT TERM

# Run main function
main "$@"
