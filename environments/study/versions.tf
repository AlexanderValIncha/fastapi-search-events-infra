terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30.0, < 6.0.0"
    }
  }

  backend "gcs" {
    # Intentionally empty: real bucket/prefix are supplied at `terraform
    # init -backend-config=backend.hcl` time (see backend.hcl.example).
    # This avoids hardcoding a real project/bucket name in version control.
  }
}
