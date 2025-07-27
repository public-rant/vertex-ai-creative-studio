#!/bin/bash
set -e

# Terraform Deployment Script for MCP Genmedia + Gemini CLI Infrastructure
# This script manages infrastructure deployment using Terraform

echo "🏗️  Managing MCP Genmedia + Gemini CLI infrastructure with Terraform..."

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
    log "Checking Terraform deployment requirements..."

    if ! command_exists terraform; then
        log "❌ Terraform not found. Please install: https://learn.hashicorp.com/tutorials/terraform/install-cli"
        exit 1
    fi

    if ! command_exists gcloud; then
        log "❌ Google Cloud CLI not found. Please install: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi

    # Check if authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
        log "❌ Not authenticated with Google Cloud. Run 'gcloud auth login'"
        exit 1
    fi

    # Check Terraform version
    local tf_version
    tf_version=$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || echo "unknown")
    log "✅ Terraform version: $tf_version"
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

    # Load from terraform.tfvars if it exists
    if [ -f deployment/terraform/terraform.tfvars ]; then
        log "✅ Found terraform.tfvars file"
    elif [ -f deployment/terraform/terraform.tfvars.example ]; then
        log "⚠️  terraform.tfvars not found. Please copy from terraform.tfvars.example"
        log "   cp deployment/terraform/terraform.tfvars.example deployment/terraform/terraform.tfvars"
        log "   Edit deployment/terraform/terraform.tfvars with your values"
        exit 1
    fi

    # Check required environment variables for authentication
    if [ -z "$GOOGLE_APPLICATION_CREDENTIALS" ] && [ -z "$GOOGLE_CREDENTIALS" ]; then
        log "ℹ️  Using gcloud default credentials"
        export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/application_default_credentials.json"
    fi
}

# Function to initialize Terraform
terraform_init() {
    log "Initializing Terraform..."

    cd deployment/terraform

    # Initialize Terraform
    terraform init -upgrade

    # Validate configuration
    terraform validate

    log "✅ Terraform initialized successfully"
    cd ../..
}

# Function to plan Terraform changes
terraform_plan() {
    log "Planning Terraform changes..."

    cd deployment/terraform

    # Generate and show plan
    terraform plan -out=tfplan

    log "✅ Terraform plan generated"
    log "📋 Review the plan above before applying"
    cd ../..
}

# Function to apply Terraform changes
terraform_apply() {
    log "Applying Terraform changes..."

    cd deployment/terraform

    # Check if plan exists
    if [ ! -f tfplan ]; then
        log "❌ No Terraform plan found. Run 'plan' command first."
        cd ../..
        exit 1
    fi

    # Apply the plan
    terraform apply tfplan

    # Remove the plan file
    rm -f tfplan

    log "✅ Terraform apply completed"
    cd ../..
}

# Function to destroy infrastructure
terraform_destroy() {
    log "⚠️  Destroying Terraform infrastructure..."

    echo "This will destroy all infrastructure managed by Terraform."
    read -p "Are you sure you want to continue? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        log "❌ Destroy cancelled"
        exit 1
    fi

    cd deployment/terraform

    # Destroy infrastructure
    terraform destroy -auto-approve

    log "✅ Infrastructure destroyed"
    cd ../..
}

# Function to show Terraform outputs
terraform_output() {
    log "Showing Terraform outputs..."

    cd deployment/terraform

    # Check if state exists
    if [ ! -f terraform.tfstate ]; then
        log "❌ No Terraform state found. Infrastructure may not be deployed."
        cd ../..
        exit 1
    fi

    # Show outputs
    terraform output

    cd ../..
}

# Function to format Terraform files
terraform_format() {
    log "Formatting Terraform files..."

    cd deployment/terraform

    # Format files
    terraform fmt -recursive

    log "✅ Terraform files formatted"
    cd ../..
}

# Function to validate Terraform configuration
terraform_validate() {
    log "Validating Terraform configuration..."

    cd deployment/terraform

    # Validate configuration
    terraform validate

    # Check formatting
    if ! terraform fmt -check -recursive; then
        log "⚠️  Terraform files need formatting. Run 'format' command."
    else
        log "✅ Terraform formatting is correct"
    fi

    log "✅ Terraform configuration is valid"
    cd ../..
}

# Function to import existing resources
terraform_import() {
    local resource_type="$1"
    local resource_name="$2"
    local resource_id="$3"

    if [ -z "$resource_type" ] || [ -z "$resource_name" ] || [ -z "$resource_id" ]; then
        log "❌ Usage: $0 import <resource_type> <resource_name> <resource_id>"
        log "   Example: $0 import google_storage_bucket.genmedia my-project-genmedia"
        exit 1
    fi

    log "Importing existing resource..."

    cd deployment/terraform

    # Import resource
    terraform import "$resource_type.$resource_name" "$resource_id"

    log "✅ Resource imported successfully"
    cd ../..
}

# Function to show state information
terraform_state() {
    local action="${1:-list}"

    cd deployment/terraform

    case "$action" in
        "list")
            log "Listing Terraform state resources..."
            terraform state list
            ;;
        "show")
            local resource="$2"
            if [ -z "$resource" ]; then
                log "❌ Usage: $0 state show <resource_name>"
                cd ../..
                exit 1
            fi
            log "Showing state for resource: $resource"
            terraform state show "$resource"
            ;;
        "pull")
            log "Pulling remote state..."
            terraform state pull
            ;;
        *)
            log "❌ Unknown state action: $action"
            log "   Available actions: list, show, pull"
            cd ../..
            exit 1
            ;;
    esac

    cd ../..
}

# Function to create workspace
terraform_workspace() {
    local action="${1:-list}"
    local workspace_name="$2"

    cd deployment/terraform

    case "$action" in
        "list")
            log "Listing Terraform workspaces..."
            terraform workspace list
            ;;
        "new")
            if [ -z "$workspace_name" ]; then
                log "❌ Usage: $0 workspace new <workspace_name>"
                cd ../..
                exit 1
            fi
            log "Creating workspace: $workspace_name"
            terraform workspace new "$workspace_name"
            ;;
        "select")
            if [ -z "$workspace_name" ]; then
                log "❌ Usage: $0 workspace select <workspace_name>"
                cd ../..
                exit 1
            fi
            log "Selecting workspace: $workspace_name"
            terraform workspace select "$workspace_name"
            ;;
        "delete")
            if [ -z "$workspace_name" ]; then
                log "❌ Usage: $0 workspace delete <workspace_name>"
                cd ../..
                exit 1
            fi
            log "Deleting workspace: $workspace_name"
            terraform workspace delete "$workspace_name"
            ;;
        *)
            log "❌ Unknown workspace action: $action"
            log "   Available actions: list, new, select, delete"
            cd ../..
            exit 1
            ;;
    esac

    cd ../..
}

# Function to backup state
backup_state() {
    log "Backing up Terraform state..."

    cd deployment/terraform

    # Create backup directory
    mkdir -p ../../backups/terraform

    # Backup state file
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)

    if [ -f terraform.tfstate ]; then
        cp terraform.tfstate "../../backups/terraform/terraform.tfstate.backup.$timestamp"
        log "✅ State backed up to backups/terraform/terraform.tfstate.backup.$timestamp"
    else
        log "⚠️  No state file found to backup"
    fi

    cd ../..
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [COMMAND] [ARGS...]

Infrastructure Management Commands:
  init         Initialize Terraform
  plan         Generate execution plan
  apply        Apply changes from plan
  destroy      Destroy all infrastructure
  output       Show Terraform outputs

Development Commands:
  format       Format Terraform files
  validate     Validate configuration

State Management:
  state        Manage Terraform state
    list       List state resources
    show       Show specific resource
    pull       Pull remote state
  backup       Backup state file

Workspace Management:
  workspace    Manage workspaces
    list       List workspaces
    new        Create workspace
    select     Select workspace
    delete     Delete workspace

Advanced Commands:
  import       Import existing resource

Examples:
  $0 init                           # Initialize Terraform
  $0 plan                          # Generate plan
  $0 apply                         # Apply changes
  $0 output                        # Show outputs
  $0 state list                    # List state resources
  $0 workspace new staging         # Create staging workspace
  $0 import google_storage_bucket.genmedia my-bucket

Environment Variables:
  GOOGLE_APPLICATION_CREDENTIALS   Path to service account key
  GOOGLE_CREDENTIALS              Service account key content

Files:
  deployment/terraform/terraform.tfvars   Terraform variables
  deployment/terraform/main.tf            Main configuration

EOF
}

# Function for complete deployment workflow
deploy_complete() {
    log "🚀 Starting complete deployment workflow..."

    terraform_init
    terraform_plan

    echo ""
    log "📋 Review the plan above"
    read -p "Do you want to apply these changes? (yes/no): " confirm

    if [ "$confirm" = "yes" ]; then
        terraform_apply
        terraform_output
        log "✅ Complete deployment finished successfully"
    else
        log "❌ Deployment cancelled"
        exit 1
    fi
}

# Main function
main() {
    local command="${1:-help}"
    shift || true

    case "$command" in
        "init")
            check_requirements
            load_environment
            terraform_init
            ;;
        "plan")
            check_requirements
            load_environment
            terraform_plan
            ;;
        "apply")
            check_requirements
            load_environment
            terraform_apply
            ;;
        "destroy")
            check_requirements
            load_environment
            terraform_destroy
            ;;
        "output")
            check_requirements
            load_environment
            terraform_output
            ;;
        "format")
            check_requirements
            terraform_format
            ;;
        "validate")
            check_requirements
            load_environment
            terraform_validate
            ;;
        "state")
            check_requirements
            load_environment
            terraform_state "$@"
            ;;
        "workspace")
            check_requirements
            load_environment
            terraform_workspace "$@"
            ;;
        "import")
            check_requirements
            load_environment
            terraform_import "$@"
            ;;
        "backup")
            backup_state
            ;;
        "deploy")
            check_requirements
            load_environment
            deploy_complete
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
trap 'log "⚠️  Terraform operation interrupted"; exit 1' INT TERM

# Ensure we're in the right directory
if [ ! -f "CONTAINER_DEPLOYMENT_PLAN.md" ]; then
    log "❌ This script must be run from the mcp-genmedia directory"
    exit 1
fi

# Run main function
main "$@"
