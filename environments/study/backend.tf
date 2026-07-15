# The actual `backend "gcs" {}` block lives in versions.tf, deliberately
# empty. Real values are passed via `-backend-config=backend.hcl`, generated
# from backend.hcl.example, so that no real bucket name is committed.
