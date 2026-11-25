# Secrets come from Infisical, never from the repository.
# Terraform authenticates with a machine identity (Universal Auth). Its credentials
# are kept in Infisical (prod, folder /ci) and injected as TF_VAR_* by the CLI:
#   infisical run --env=prod --path=/ci -- terraform apply

variable "infisical_client_id" {
  description = "Client ID of the Infisical machine identity."
  type        = string
  sensitive   = true
}

variable "infisical_client_secret" {
  description = "Client secret of the Infisical machine identity."
  type        = string
  sensitive   = true
}

variable "infisical_workspace_id" {
  description = "Infisical project ID (Project Settings > General). Not a secret; set it in terraform.tfvars."
  type        = string
}

variable "infisical_env_slug" {
  description = "Infisical environment that holds the production secrets."
  type        = string
  default     = "prod"
}

provider "infisical" {
  auth = {
    universal = {
      client_id     = var.infisical_client_id
      client_secret = var.infisical_client_secret
    }
  }
}

data "infisical_secrets" "app" {
  env_slug     = var.infisical_env_slug
  workspace_id = var.infisical_workspace_id
  folder_path  = "/"
}

locals {
  # RDS rejects '/', '@', '"' and spaces in passwords: use a plain alphanumeric value.
  db_password = data.infisical_secrets.app.secrets["POSTGRES_PASSWORD"].value
}
