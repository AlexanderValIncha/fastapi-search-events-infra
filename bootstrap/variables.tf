variable "project_id" {
  description = "GCP project ID where bootstrap resources are created. No default on purpose: this must never be a placeholder value applied by accident."
  type        = string
}

variable "region" {
  description = "Primary region for regional resources (Artifact Registry repo, state bucket)."
  type        = string
  default     = "europe-west1"
}

variable "environment" {
  description = "Logical environment name. Only 'study' is expected to be used with this repository."
  type        = string
  default     = "study"
}

variable "application_name" {
  description = "Short application name used to derive resource names."
  type        = string
  default     = "hotel-search-ingestion"
}

variable "labels" {
  description = "Common labels applied to bootstrap resources."
  type        = map(string)
  default = {
    application = "hotel-search-ingestion"
    environment = "study"
    managed_by  = "terraform"
    purpose     = "technical-study"
  }
}
