terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }

  cloud {
    organization = "Goosefleet-dev"

    workspaces {
      name = "infrastructure"
    }
  }
}

# Define the DigitalOcean Personal Access Token
variable "DO_PAT" {}

# Configure the DigitalOcean Provider
provider "digitalocean" {
  token = var.DO_PAT
}

variable "SECRET_KEY_BASE" {
  type = string
}

variable "CLOAK_KEY" {
  type = string
}

variable "CCP_SSO_CLIENT_ID" {
  type = string
}
variable "CCP_SSO_SECRET_KEY" {
  type = string
}

variable "AA_OAUTH2_OIDC_ISSUER_URL" {
  type    = string
  default = ""
}

variable "AA_OAUTH2_CLIENT_ID" {
  type    = string
  default = ""
}

variable "AA_OAUTH2_CLIENT_SECRET" {
  type    = string
  default = ""
}

variable "AA_EMAIL_DOMAINS" {
  type    = string
  default = "*"
}

module "wanderer-production" {
  source = "./modules/wanderer"

  SECRET_KEY_BASE           = var.SECRET_KEY_BASE
  CLOAK_KEY                 = var.CLOAK_KEY
  CCP_SSO_CLIENT_ID         = var.CCP_SSO_CLIENT_ID
  CCP_SSO_SECRET_KEY        = var.CCP_SSO_SECRET_KEY
  AA_OAUTH2_OIDC_ISSUER_URL = var.AA_OAUTH2_OIDC_ISSUER_URL
  AA_OAUTH2_CLIENT_ID       = var.AA_OAUTH2_CLIENT_ID
  AA_OAUTH2_CLIENT_SECRET   = var.AA_OAUTH2_CLIENT_SECRET
  AA_EMAIL_DOMAINS          = var.AA_EMAIL_DOMAINS
}

