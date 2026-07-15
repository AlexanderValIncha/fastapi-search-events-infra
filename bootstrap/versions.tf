terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30.0, < 6.0.0"
    }
  }

  # Bootstrap intentionally uses LOCAL state.
  #
  # The GCS bucket that will hold remote state for the rest of this
  # repository is itself created by this stack, so it cannot depend on
  # itself. See bootstrap/README.md for the full explanation and the
  # documented steps to migrate this stack's state to GCS afterwards
  # (optional, and not required for the "study" workload to work).
}
