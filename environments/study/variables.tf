variable "project_id" {
  description = "GCP project ID for the study workload. No default: must always be explicit."
  type        = string
}

variable "region" {
  description = "Primary region for all regional resources."
  type        = string
  default     = "europe-west1"
}

variable "environment" {
  description = "Logical environment name."
  type        = string
  default     = "study"
}

variable "application_name" {
  description = "Short application name used to derive resource names."
  type        = string
  default     = "hotel-search-ingestion"
}

variable "partner_id" {
  description = "Identifier of the single OTA partner served by this study deployment. Used as the Cloud Run PARTNER_ID env var and as a GCS archive path prefix."
  type        = string
  default     = "demo-ota"
}

variable "container_image" {
  description = <<-EOT
    Fully qualified, immutable Cloud Run container image reference,
    pinned by digest (never by tag), e.g.:

      europe-west1-docker.pkg.dev/my-project/hotel-search-api/hotel-search-api@sha256:<64-hex-chars>

    No default: every deployment must explicitly pin an image.
  EOT
  type        = string

  validation {
    condition     = can(regex("@sha256:[0-9a-f]{64}$", var.container_image))
    error_message = "container_image must reference an image by immutable digest (...@sha256:<64 hex chars>), not by a mutable tag such as ':latest'."
  }

  validation {
    condition     = !can(regex(":latest", var.container_image))
    error_message = "container_image must not use the 'latest' tag."
  }
}

variable "cloud_run_min_instances" {
  description = "Minimum number of Cloud Run instances (reduces cold starts)."
  type        = number
  default     = 1
}

variable "cloud_run_max_instances" {
  description = "Maximum number of Cloud Run instances (initial cost/capacity ceiling, not load-tested)."
  type        = number
  default     = 20
}

variable "cloud_run_concurrency" {
  description = "Maximum concurrent requests per Cloud Run instance."
  type        = number
  default     = 80
}

variable "cloud_run_cpu" {
  description = "vCPUs allocated per Cloud Run instance."
  type        = number
  default     = 1
}

variable "cloud_run_memory" {
  description = "Memory allocated per Cloud Run instance."
  type        = string
  default     = "512Mi"
}

variable "archive_retention_days" {
  description = "Number of days after which archived events in GCS are deleted."
  type        = number
  default     = 365
}

variable "labels" {
  description = "Common labels applied to all workload resources."
  type        = map(string)
  default = {
    application = "hotel-search-ingestion"
    environment = "study"
    managed_by  = "terraform"
    purpose     = "technical-study"
  }
}
