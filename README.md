# terraform-azurerm-webapp-appgw

This terraform module deploys a Web App on dedicated app service plan, with autoscaling and a application gateway, in Azure.

The following resources will be created by the module:
- App service plan (S1)
- Web application
- Auto scale settings for app service plan.
- Web application gateway
- Public IP
- VNET and subnet where the application gateway is placed

The goal of the module is to sets up a application gateway that fronts the web application. It allows only HTTPS traffic and redirects HTTP to HTTPS. However, some limitations of the terraform and the azure provider will require you to perform manual configuration after running terraform.

## Usage

```hcl

resource "azurerm_resource_group" "rsg" {
  name     = "myprotectedwebapp-rg"
  location = "westeurope"
}


  source                     = "innovationnorway/webapp-appgw/azurerm"
  version                    = "0.1.0-pre"
  web_app_name               = "myprotectedwebapp"
  resource_group_name        = "${azurerm_resource_group.rsg.name}"
  location                   = "${azurerm_resource_group.rsg.location}"
  agw_certificate_file_name  = "mycert.pfx"
  agw_certificate_password   = "Supers3cretP@55w0rd"
   

```


## Limitations
There are some limitations in the module due to constraints in the resources provided by terraform. This means that some manual configuration needs to be performed after using this module.

### HTTP to HTTPS redirect
Terraform does not yet support adding a listener to listener redirect, so setting 80 to 443 redirect needs to be configured manually.

Terraform Azure provider issue: [1576](https://github.com/terraform-providers/terraform-provider-azurerm/issues/1576)

### Pick Hostname from Backend Address
Terraform does not support setting "pick host name from backend address" option to true in the backend pool (which gives a lot of problem when setting up app gw with web apps and not vms), so this needs to be done manually

Terraform Azure provider issue: [1875](https://github.com/terraform-providers/terraform-provider-azurerm/issues/1875)

### Ip restriction on web application
Due to how public IP resource function - no ip assigned to the resource "public ip address" until it is being used. The only user of the public ip is the application gateway and ss the app gateway uses the web application the web application must be created first. This means that the ip address does not exist when creating the web app, hence no ip restriction can be set. This needs to be done manually.

