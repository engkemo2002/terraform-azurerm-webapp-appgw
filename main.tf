resource "azurerm_app_service_plan" "serviceplan" {
  name                = "${local.app_service_plan_name}"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"

  sku {
    tier = "Standard"
    size = "S1"
  }

  tags = "${merge(var.tags, map("environment", var.environment), map("release", var.release))}"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.web_app_name}-${var.environment}-vnet"
  resource_group_name = "${var.resource_group_name}"
  address_space       = ["${var.agw_vnet_address_space}"]
  location            = "${var.location}"
}

# Create subnet
resource "azurerm_subnet" "subnet" {
  name                 = "${var.web_app_name}-${var.environment}-subnet"
  resource_group_name  = "${var.resource_group_name}"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  address_prefix       = "${var.agw_subnet_prefix}"
}

# Create public IP (PIP)
resource "azurerm_public_ip" "pip" {
  name                         = "${var.web_app_name}-${var.environment}-pip"
  location                     = "${var.location}"
  resource_group_name          = "${var.resource_group_name}"
  public_ip_address_allocation = "dynamic"
  domain_name_label            = "${var.web_app_name}-${var.environment}"
}

resource "azurerm_app_service" "webapp" {
  name                    = "${local.web_app_name}"
  location                = "${var.location}"
  resource_group_name     = "${var.resource_group_name}"
  app_service_plan_id     = "${azurerm_app_service_plan.serviceplan.id}"
  https_only              = false
  client_affinity_enabled = false

  tags = "${merge(var.tags, map("environment", var.environment), map("release", var.release))}"

  site_config {
    always_on = true

    ftps_state = "FtpsOnly"

   # Doesnt work, no ip is assigned to the pip before the app gw has been created
   # No app gw is created before the web app has been created
   # ip_restriction {
   #   ip_address  = "${azurerm_public_ip.pip.ip_address}"
   #   subnet_mask = "255.255.255.255"
   # }
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = "${var.app_settings}"

  lifecycle {
    ignore_changes = ["app_settings"]
  }
}

resource "azurerm_autoscale_setting" "app_service_auto_scale" {
  name                = "${local.autoscale_settings_name}"
  resource_group_name = "${var.resource_group_name}"
  location            = "${var.location}"
  target_resource_id  = "${azurerm_app_service_plan.serviceplan.id}"

  profile {
    name = "Scale on CPU usage"

    capacity {
      default = 1
      minimum = 1
      maximum = "${azurerm_app_service_plan.serviceplan.maximum_number_of_workers}"
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = "${azurerm_app_service_plan.serviceplan.id}"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT10M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = "${azurerm_app_service_plan.serviceplan.id}"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }

  notification {
    # operation = "Scale"

    email {
      send_to_subscription_administrator    = true
      send_to_subscription_co_administrator = true
    }
  }
}

resource "azurerm_application_gateway" "appgw" {
  name                = "${var.web_app_name}-${var.environment}-agw"
  resource_group_name = "${var.resource_group_name}"
  location            = "${var.location}"

  # Web Application Firewall (WAF)
  sku {
    name     = "WAF_Medium"
    tier     = "WAF"
    capacity = 1
  }

  waf_configuration {
    firewall_mode    = "Detection"
    rule_set_type    = "OWASP"
    rule_set_version = "3.0"
    enabled          = true
  }

  gateway_ip_configuration {
    name      = "ipconfig"
    subnet_id = "${azurerm_subnet.subnet.id}"
  }

  # front end config
  frontend_port {
    name = "https-port"
    port = 443
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "${var.web_app_name}-${var.environment}-pip"
    public_ip_address_id = "${azurerm_public_ip.pip.id}"
  }

  # backend config
  backend_address_pool {
    name = "backend-pool"

    # add app service default host name to packend pool
    fqdn_list = ["${azurerm_app_service.webapp.default_site_hostname}"]
  }

  backend_http_settings {
    name                  = "backend-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
    probe_name            = "HealthProbe"
  }

  # http listeners
  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "${var.web_app_name}-${var.environment}-pip"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  http_listener {
    name                           = "https-listener"
    frontend_ip_configuration_name = "${var.web_app_name}-${var.environment}-pip"
    frontend_port_name             = "https-port"
    protocol                       = "Https"
    ssl_certificate_name           = "agw-certificate"
  }

  #Set rule to forward traffic on https port to webapp, http to https redirect not part of the configuration.
  request_routing_rule {
    name                       = "https-rule"
    rule_type                  = "Basic"
    http_listener_name         = "https-listener"
    backend_address_pool_name  = "backend-pool"
    backend_http_settings_name = "backend-settings"
  }

  probe {
    name                = "HealthProbe"
    protocol            = "http"
    path                = "/"
    host                = "${azurerm_app_service.webapp.default_site_hostname}"
    interval            = "${var.agw_probe_interval}"
    timeout             = "${var.agw_probe_timeout}"
    unhealthy_threshold = "${var.agw_probe_unhealthy_threshold}"

    match {
      status_code = ["${var.agw_probe_match_statuscode}"]
      body        = ""
    }
  }

  ssl_certificate {
    name     = "agw-certificate"
    data     = "${base64encode(file("${var.agw_certificate_file_name}"))}"
    password = "${var.agw_certificate_password}"
  }
}
