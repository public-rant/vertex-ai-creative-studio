# Terraform configuration for MCP Genmedia + Gemini CLI infrastructure
terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 4.0"
    }
  }
}

# Variables
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "genmedia_bucket_name" {
  description = "Name for the genmedia storage bucket"
  type        = string
  default     = null
}

variable "brave_api_key" {
  description = "Brave Search API key"
  type        = string
  sensitive   = true
  default     = ""
}

# Local values
locals {
  bucket_name = var.genmedia_bucket_name != null ? var.genmedia_bucket_name : "${var.project_id}-genmedia"
}

# Configure the Google Cloud Provider
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "cloudbuild.googleapis.com",
    "run.googleapis.com",
    "containerregistry.googleapis.com",
    "artifactregistry.googleapis.com",
    "storage.googleapis.com",
    "aiplatform.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com"
  ])

  service = each.key
  project = var.project_id

  disable_dependent_services = false
  disable_on_destroy         = false
}

# Create service account for Cloud Build
resource "google_service_account" "cloudbuild" {
  account_id   = "cloudbuild"
  display_name = "Cloud Build Service Account for MCP Genmedia"
  description  = "Service account used by Cloud Build for MCP Genmedia deployments"

  depends_on = [google_project_service.required_apis]
}

# Create service account for Cloud Run
resource "google_service_account" "cloudrun" {
  account_id   = "mcp-genmedia-runner"
  display_name = "Cloud Run Service Account for MCP Genmedia"
  description  = "Service account used by Cloud Run for MCP Genmedia application"

  depends_on = [google_project_service.required_apis]
}

# IAM bindings for Cloud Build service account
resource "google_project_iam_member" "cloudbuild_roles" {
  for_each = toset([
    "roles/cloudbuild.builds.builder",
    "roles/run.admin",
    "roles/storage.admin",
    "roles/secretmanager.secretAccessor",
    "roles/iam.serviceAccountUser"
  ])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"

  depends_on = [google_service_account.cloudbuild]
}

# IAM bindings for Cloud Run service account
resource "google_project_iam_member" "cloudrun_roles" {
  for_each = toset([
    "roles/aiplatform.user",
    "roles/storage.objectAdmin",
    "roles/secretmanager.secretAccessor"
  ])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.cloudrun.email}"

  depends_on = [google_service_account.cloudrun]
}

# Create Cloud Storage bucket for genmedia files
resource "google_storage_bucket" "genmedia" {
  name     = local.bucket_name
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age                   = 30
      matches_storage_class = ["STANDARD"]
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  depends_on = [google_project_service.required_apis]
}

# Grant Cloud Run service account access to the bucket
resource "google_storage_bucket_iam_member" "genmedia_bucket_access" {
  bucket = google_storage_bucket.genmedia.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.cloudrun.email}"

  depends_on = [google_storage_bucket.genmedia, google_service_account.cloudrun]
}

# Create Secret Manager secret for Brave API key
resource "google_secret_manager_secret" "brave_api_key" {
  secret_id = "brave-api-key"

  replication {
    automatic = true
  }

  depends_on = [google_project_service.required_apis]
}

# Create secret version if API key is provided
resource "google_secret_manager_secret_version" "brave_api_key" {
  count = var.brave_api_key != "" ? 1 : 0

  secret      = google_secret_manager_secret.brave_api_key.id
  secret_data = var.brave_api_key

  depends_on = [google_secret_manager_secret.brave_api_key]
}

# Create Artifact Registry repository
resource "google_artifact_registry_repository" "mcp_genmedia" {
  location      = var.region
  repository_id = "mcp-genmedia"
  description   = "Container images for MCP Genmedia application"
  format        = "DOCKER"

  cleanup_policies {
    id     = "keep-minimum-versions"
    action = "KEEP"
    most_recent_versions {
      keep_count = 10
    }
  }

  cleanup_policies {
    id     = "delete-old-versions"
    action = "DELETE"
    condition {
      older_than = "2592000s" # 30 days
    }
  }

  depends_on = [google_project_service.required_apis]
}

# Grant Cloud Build access to Artifact Registry
resource "google_artifact_registry_repository_iam_member" "cloudbuild_access" {
  location   = google_artifact_registry_repository.mcp_genmedia.location
  repository = google_artifact_registry_repository.mcp_genmedia.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.cloudbuild.email}"

  depends_on = [google_artifact_registry_repository.mcp_genmedia, google_service_account.cloudbuild]
}

# Create Cloud Build trigger for automatic deployments
resource "google_cloudbuild_trigger" "mcp_genmedia_deploy" {
  name        = "mcp-genmedia-deploy"
  description = "Deploy MCP Genmedia application on git push"

  github {
    owner = "your-github-username"  # Update this
    name  = "vertex-ai-creative-studio"  # Update this
    push {
      branch = "^main$"
    }
  }

  included_files = [
    "experiments/mcp-genmedia/**"
  ]

  filename = "experiments/mcp-genmedia/deployment/cloudbuild.yaml"

  substitutions = {
    _REGION           = var.region
    _GENMEDIA_BUCKET  = google_storage_bucket.genmedia.name
  }

  service_account = google_service_account.cloudbuild.id

  depends_on = [
    google_project_service.required_apis,
    google_service_account.cloudbuild,
    google_storage_bucket.genmedia
  ]
}

# Deploy Cloud Run service
resource "google_cloud_run_service" "mcp_genmedia" {
  name     = "mcp-genmedia"
  location = var.region

  template {
    spec {
      service_account_name = google_service_account.cloudrun.email
      container_concurrency = 10
      timeout_seconds = 900

      containers {
        image = "gcr.io/${var.project_id}/mcp-genmedia:latest"

        ports {
          container_port = 8080
        }

        env {
          name  = "PROJECT_ID"
          value = var.project_id
        }

        env {
          name  = "LOCATION"
          value = var.region
        }

        env {
          name  = "GENMEDIA_BUCKET"
          value = google_storage_bucket.genmedia.name
        }

        env {
          name = "BRAVE_API_KEY"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.brave_api_key.secret_id
              key  = "latest"
            }
          }
        }

        resources {
          limits = {
            cpu    = "2000m"
            memory = "2Gi"
          }
        }

        liveness_probe {
          http_get {
            path = "/health"
            port = 8080
          }
          initial_delay_seconds = 30
          period_seconds        = 10
          timeout_seconds       = 5
          failure_threshold     = 3
        }

        startup_probe {
          http_get {
            path = "/health"
            port = 8080
          }
          initial_delay_seconds = 10
          period_seconds        = 3
          timeout_seconds       = 1
          failure_threshold     = 30
        }
      }
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale" = "0"
        "autoscaling.knative.dev/maxScale" = "10"
        "run.googleapis.com/cpu-throttling" = "false"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    google_project_service.required_apis,
    google_service_account.cloudrun,
    google_storage_bucket.genmedia,
    google_secret_manager_secret.brave_api_key
  ]

  lifecycle {
    ignore_changes = [
      template[0].spec[0].containers[0].image,
    ]
  }
}

# Make the Cloud Run service publicly accessible
resource "google_cloud_run_service_iam_member" "public_access" {
  service  = google_cloud_run_service.mcp_genmedia.name
  location = google_cloud_run_service.mcp_genmedia.location
  role     = "roles/run.invoker"
  member   = "allUsers"

  depends_on = [google_cloud_run_service.mcp_genmedia]
}

# Outputs
output "project_id" {
  description = "The GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "The GCP region"
  value       = var.region
}

output "genmedia_bucket_name" {
  description = "Name of the created genmedia storage bucket"
  value       = google_storage_bucket.genmedia.name
}

output "cloud_run_url" {
  description = "URL of the deployed Cloud Run service"
  value       = google_cloud_run_service.mcp_genmedia.status[0].url
}

output "cloudbuild_service_account" {
  description = "Email of the Cloud Build service account"
  value       = google_service_account.cloudbuild.email
}

output "cloudrun_service_account" {
  description = "Email of the Cloud Run service account"
  value       = google_service_account.cloudrun.email
}

output "artifact_registry_repository" {
  description = "Name of the Artifact Registry repository"
  value       = google_artifact_registry_repository.mcp_genmedia.name
}

output "secret_manager_secret_id" {
  description = "ID of the Secret Manager secret for Brave API key"
  value       = google_secret_manager_secret.brave_api_key.secret_id
}
