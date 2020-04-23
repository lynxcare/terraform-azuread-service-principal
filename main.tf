data "azurerm_client_config" "main" {}

data "azurerm_role_definition" "main" {
  count = var.role != "" ? 1 : 0
  name  = var.role
}

data "azurerm_subscription" "main" {}

resource "azuread_application" "main" {
  name = var.name
  identifier_uris = [
    format("http://%s", var.name)
  ]
  available_to_other_tenants = false
}

resource "azuread_service_principal" "main" {
  application_id = azuread_application.main.application_id
}

resource "time_rotating" "main" {
  rotation_rfc3339 = var.end_date != "" ? var.end_date : null
  rotation_years   = var.end_date == "" ? var.years : null
}

resource "random_password" "main" {
  count  = var.password == "" ? 1 : 0
  length = 32

  keepers = {
    end_date = time_rotating.main.rotation_rfc3339
  }
}

resource "azuread_service_principal_password" "main" {
  count                = var.password != null ? 1 : 0
  service_principal_id = azuread_service_principal.main.id
  value                = coalesce(var.password, random_password.main[0].result)
  end_date             = time_rotating.main.rotation_rfc3339
}

resource "azurerm_role_assignment" "main" {
  for_each           = var.role != "" ? local.scopes : toset([])
  scope              = each.key
  role_definition_id = format("%s%s", data.azurerm_subscription.main.id, data.azurerm_role_definition.main[0].id)
  principal_id       = azuread_service_principal.main.id
}
