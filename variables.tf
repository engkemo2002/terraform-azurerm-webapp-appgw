variable "resource_group_name" {
  description = "The resource group where the resources should be created."
}

variable "location" {
  default     = "westeurope"
  description = "The azure datacenter location where the resources should be created."
}
variable "web_app_name" {
  description = "The name for the function app. Without environment naming."
}

variable "app_settings" {
  default     = {}
  type        = "map"
  description = "Application settings to insert on creating the function app. Following updates will be ignored, and has to be set manually. Updates done on application deploy or in portal will not affect terraform state file."
}

variable "agw_vnet_address_space" {
  default = "10.0.0.0/16"
  description = "The virtual network the application gateway resides in. Format x.x.x.x/yy"
}
variable "agw_subnet_prefix" {
  default = "10.0.1.240/28"
  description = "The subnet the application gateway resides in, nothing else can be deployed into that subnet. Should be in format x.x.x.x/yy"
}

variable "agw_probe_interval" {
  default     = 90
  description = ""
}

variable "agw_probe_timeout" {
  default     = 30
  description = ""
}

variable "agw_probe_unhealthy_threshold" {
  default     = 3
  description = ""
}

variable "agw_probe_match_statuscode" {
  default     = "200"
  description = ""
}

variable "agw_certificate_file_name" {
  description = "The file name of the certificate used to secure the https port"
}

variable "agw_certificate_password" {
  description = "The password to the certificate used to secure the https port"
}


variable "tags" {
  description = "A map of tags to add to all resources"
  type        = "map"

  default = {}
}

variable "environment" {
  default     = "lab"
  description = "The environment where the infrastructure is deployed."
}

variable "release" {
  default     = ""
  description = "The release the deploy is based on."
}
