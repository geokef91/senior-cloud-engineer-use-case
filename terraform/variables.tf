# ---------------------------------------------------------------------------
# Core
# ---------------------------------------------------------------------------
variable "environment" {
  description = "Deployment environment (dev | prod)"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be 'dev' or 'prod'."
  }
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "westeurope"
}

variable "project" {
  description = "Short project identifier used in resource names"
  type        = string
  default     = "usecase"
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
variable "vnet_address_space" {
  description = "Address space for the spoke VNet"
  type        = list(string)
  default     = ["10.0.0.0/24"]
}

variable "subnet_container_apps_cidr" {
  description = "CIDR for Container Apps Environment subnet (min /27)"
  type        = string
  default     = "10.0.0.0/27"
}

variable "subnet_private_endpoints_cidr" {
  description = "CIDR for private endpoints subnet"
  type        = string
  default     = "10.0.0.32/27"
}

variable "hub_vnet_id" {
  description = "Resource ID of the hub VNet to peer with"
  type        = string
  # Provided via environment-specific tfvars or CI secret
}

# ---------------------------------------------------------------------------
# Container App
# ---------------------------------------------------------------------------
variable "container_image" {
  description = "Full container image reference (e.g. myacr.azurecr.io/fastapi-app:latest)"
  type        = string
}

variable "container_cpu" {
  description = "vCPU allocated to the container"
  type        = number
  default     = 0.5
}

variable "container_memory" {
  description = "Memory allocated to the container"
  type        = string
  default     = "1Gi"
}

variable "app_min_replicas" {
  description = "Minimum replica count"
  type        = number
  default     = 1
}

variable "app_max_replicas" {
  description = "Maximum replica count"
  type        = number
  default     = 3
}

# ---------------------------------------------------------------------------
# Storage
# ---------------------------------------------------------------------------
variable "storage_account_tier" {
  description = "Storage account performance tier"
  type        = string
  default     = "Standard"
}

variable "storage_replication_type" {
  description = "Storage account replication type"
  type        = string
  default     = "LRS"
  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.storage_replication_type)
    error_message = "storage_replication_type must be one of: LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS."
  }
}

# ---------------------------------------------------------------------------
# Key Vault
# ---------------------------------------------------------------------------
variable "key_vault_sku" {
  description = "Key Vault SKU (standard | premium)"
  type        = string
  default     = "standard"
  validation {
    condition     = contains(["standard", "premium"], var.key_vault_sku)
    error_message = "key_vault_sku must be 'standard' or 'premium'."
  }
}

# ---------------------------------------------------------------------------
# CI/CD
# ---------------------------------------------------------------------------
variable "cicd_principal_id" {
  description = "Object ID of the CI/CD service principal that manages Key Vault secrets. Leave empty to skip."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Tags
# ---------------------------------------------------------------------------
variable "tags" {
  description = "Additional tags to merge onto all resources"
  type        = map(string)
  default     = {}
}
