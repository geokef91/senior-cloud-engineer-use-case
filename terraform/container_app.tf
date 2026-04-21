# ---------------------------------------------------------------------------
# Log Analytics Workspace (used by Container Apps Environment)
# ---------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = var.environment == "prod" ? 90 : 30 # 90d for prod audit requirements
  tags                = local.tags
}

# ---------------------------------------------------------------------------
# Container Apps Environment
# internal_load_balancer_enabled = true → no public endpoint, VNet-only
# ---------------------------------------------------------------------------
resource "azurerm_container_app_environment" "main" {
  name                           = "cae-${local.name_suffix}"
  resource_group_name            = azurerm_resource_group.main.name
  location                       = azurerm_resource_group.main.location
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.main.id
  infrastructure_subnet_id       = azurerm_subnet.container_apps.id
  internal_load_balancer_enabled = true # Private ingress only — no public IP
  tags                           = local.tags
}

# ---------------------------------------------------------------------------
# Container App — FastAPI
# ---------------------------------------------------------------------------
resource "azurerm_container_app" "api" {
  name                         = "ca-api-${local.name_suffix}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Multiple" # Enables blue-green; traffic_weight controls rollout
  tags                         = local.tags

  # Wait for RBAC assignments to propagate before the app starts.
  # Azure RBAC can take up to 2 minutes; without this the first boot gets 403.
  depends_on = [
    azurerm_role_assignment.app_storage_blob_contributor,
    azurerm_role_assignment.app_keyvault_secrets_user,
  ]

  # The container image is managed by the app deployment pipeline, not Terraform.
  # Ignoring it prevents Terraform from reverting the image on the next infra run.
  lifecycle {
    ignore_changes = [template[0].container[0].image]
  }

  # Attach the user-assigned managed identity so the app can authenticate
  # to Storage and Key Vault without credentials
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  template {
    min_replicas = var.app_min_replicas
    max_replicas = var.app_max_replicas

    # scale on concurrent requests instead of just replica bounds —
    # worth enabling if traffic is spiky (e.g. batch uploads)
    # scale_rule {
    #   name = "http-scaling"
    #   http_scale_rule {
    #     concurrent_requests = "50"
    #   }
    # }

    container {
      name   = "fastapi-app"
      image  = var.container_image
      cpu    = var.container_cpu
      memory = var.container_memory

      # Pass the managed identity client ID so the Azure SDK can use it
      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.app.client_id
      }

      # Storage account name injected at runtime (non-sensitive)
      env {
        name  = "STORAGE_ACCOUNT_NAME"
        value = azurerm_storage_account.main.name
      }

      # Key Vault URI injected at runtime (non-sensitive)
      env {
        name  = "KEY_VAULT_URI"
        value = azurerm_key_vault.main.vault_uri
      }

      # Health probes — required for revision_mode = "Multiple" to work correctly.
      # The platform uses these to decide when a new revision is ready for traffic.
      # Path must match the FastAPI health endpoint (add GET /health → {"status":"ok"}).
      liveness_probe {
        transport = "HTTP"
        path      = "/health"
        port      = 8000

        initial_delay           = 10
        interval_seconds        = 30
        failure_count_threshold = 3
      }

      readiness_probe {
        transport = "HTTP"
        path      = "/health"
        port      = 8000

        initial_delay           = 5
        interval_seconds        = 10
        failure_count_threshold = 3
      }
    }
  }

  # Internal ingress only — not reachable from the public internet
  ingress {
    external_enabled = false
    target_port      = 8000

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}
