terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

# Wanderer variables

variable "WANDERER_VERSION" {
  type    = string
  default = "v1.20.1"
}

variable "CLOAK_KEY" {
  type    = string
  default = ""
}

variable "SECRET_KEY_BASE" {
  type    = string
  default = ""
}

variable "CCP_SSO_CLIENT_ID" {
  type    = string
  default = ""
}
variable "CCP_SSO_SECRET_KEY" {
  type    = string
  default = ""
}


# Oauth2 Proxy variables

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

resource "random_password" "oauth_proxy_cookie_secret" {
  length           = 32
  override_special = "-_"
}

resource "digitalocean_project" "goosefleet-wanderer-production" {
  name        = "goosefleet-wanderer-production"
  description = "Goosefleet Wanderer Production Environment"
  environment = "Production"
  purpose     = "Web Application"
  is_default  = false
  resources = [
    digitalocean_app.wanderer-production.urn,
    digitalocean_database_cluster.wanderer-production-db-cluster.urn,
  ]
}

resource "digitalocean_vpc" "wanderer-production-vpc" {
  name        = "wanderer-production-vpc-network"
  description = "Production VPC network"
  region      = "nyc3"
  ip_range    = "10.10.11.0/24"
}

resource "digitalocean_app" "wanderer-production" {
  spec {
    name   = "wanderer-production"
    region = "nyc"

    # wanderer

    env {
      key   = "WEB_APP_URL"
      value = "https://wanderer-production-o3rad.ondigitalocean.app"
    }

    env {
      key   = "SECRET_KEY_BASE"
      value = var.SECRET_KEY_BASE
    }

    env {
      key   = "CLOAK_KEY"
      value = var.CLOAK_KEY
    }

    env {
      key   = "EVE_CLIENT_ID"
      value = var.CCP_SSO_CLIENT_ID
    }

    env {
      key   = "EVE_CLIENT_SECRET"
      value = var.CCP_SSO_SECRET_KEY
      type  = "SECRET"
    }

    env {
      key   = "DATABASE_URL"
      value = "postgresql://${digitalocean_database_cluster.wanderer-production-db-cluster.user}:${digitalocean_database_cluster.wanderer-production-db-cluster.password}@${digitalocean_database_cluster.wanderer-production-db-cluster.host}:${digitalocean_database_cluster.wanderer-production-db-cluster.port}/${digitalocean_database_cluster.wanderer-production-db-cluster.database}"
    }

    env {
      key   = "DATABASE_SSL_ENABLED"
      value = "true"
    }

    env {
      key   = "DATABASE_SSL_VERIFY_NONE"
      value = "true"
    }

    env {
      key   = "CUSTOM_ROUTE_BASE_URL"
      value = "http://eve-route-builder:2001"
    }

    env {
      key   = "PHX_SERVER"
      value = "true"
    }

    env {
      key   = "ECTO_IPV6"
      value = "false"
    }

    service {
      name               = "wanderer"
      instance_count     = 1
      instance_size_slug = "professional-xs"

      internal_ports = [8000]

      run_command = "sh -c 'sleep 10 && echo /app/entrypoint.sh db createdb && /app/entrypoint.sh db migrate && /app/entrypoint.sh run'"

      image {
        registry_type = "DOCKER_HUB"
        # registry      = "ryanrolds"
        # repository    = "wanderer"
        # tag           = "1dd10ee0e2efa"
        registry   = "wandererltd"
        repository = "community-edition"
        tag        = var.WANDERER_VERSION
      }
    }

    service {
      name               = "eve-route-builder"
      instance_count     = 1
      instance_size_slug = "professional-xs"
      internal_ports     = [2001]

      image {
        registry_type = "DOCKER_HUB"
        registry      = "dansylvest"
        repository    = "eve-route-builder"
        tag           = "main"
      }
    }

    # oauth2-proxy 

    env {
      key   = "OAUTH2_PROXY_PROVIDER"
      value = "oidc"
    }

    # env {
    #   key   = "OAUTH2_PROXY_ALLOWED_GROUPS"
    #   value = "Wanderer"
    # }

    env {
      key   = "OAUTH2_PROXY_OIDC_ISSUER_URL"
      value = var.AA_OAUTH2_OIDC_ISSUER_URL
    }

    env {
      key   = "OAUTH2_PROXY_COOKIE_SECRET"
      value = random_password.oauth_proxy_cookie_secret.result
      type  = "SECRET"
    }

    env {
      key   = "OAUTH2_PROXY_CLIENT_ID"
      value = var.AA_OAUTH2_CLIENT_ID
    }

    env {
      key   = "OAUTH2_PROXY_CLIENT_SECRET"
      value = var.AA_OAUTH2_CLIENT_SECRET
      type  = "SECRET"
    }

    env {
      key   = "OAUTH2_PROXY_CODE_CHALLENGE_METHOD"
      value = "S256"
    }

    env {
      key   = "OAUTH2_PROXY_EMAIL_DOMAINS"
      value = var.AA_EMAIL_DOMAINS
    }

    env {
      key   = "OAUTH2_PROXY_ALLOWED_GROUPS"
      value = "Wanderer"
    }

    # required because AA OIDC doesn't support the groups scope
    # instead, it includes groups in the profile scope
    # oidc-proxy automatically includes the groups scope
    # when OAUTH2_PROXY_ALLOWED_GROUPS is set, so we must override it
    env {
      key   = "OAUTH2_PROXY_SCOPE"
      value = "openid email profile"
    }

    # allow access to the favicon without authentication (shown in AA's auth flow)
    env {
      key   = "OAUTH2_PROXY_SKIP_AUTH_ROUTES"
      value = "GET=^/favicon.ico$"
    }

    service {
      name               = "oauth2-proxy"
      instance_size_slug = "professional-xs"

      http_port = 4180

      # This is require for two reasons:
      # Digital Ocean doesn't support quay.io iamges, so we must use the bitnami image
      # The bitnami image has a hardcoded upstream URL, so we must override it
      run_command = "oauth2-proxy --upstream=http://wanderer:8000/ --http-address=0.0.0.0:4180"

      image {
        registry_type = "DOCKER_HUB"
        registry      = "bitnami"
        repository    = "oauth2-proxy"
        tag           = "7.7.1"
      }
    }

    ingress {
      rule {
        component {
          name = "oauth2-proxy"
        }
        match {
          path {
            prefix = "/"
          }
        }
      }
    }
  }
}

resource "digitalocean_database_cluster" "wanderer-production-db-cluster" {
  name       = "wanderer-production-db-cluster"
  engine     = "pg"
  version    = "16"
  size       = "db-s-1vcpu-1gb"
  region     = "nyc3"
  node_count = 1

  lifecycle {
    # do not destoy the DB
    prevent_destroy = true
  }
}

resource "digitalocean_database_firewall" "wanderer-production-db-fw" {
  cluster_id = digitalocean_database_cluster.wanderer-production-db-cluster.id

  rule {
    type  = "app"
    value = digitalocean_app.wanderer-production.id
  }
}
