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

resource "random_password" "setup_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "digitalocean_project" "goosefleet-production" {
  name        = "goosefleet-production"
  description = "Goosefleet production environment"
  environment = "Production"
  purpose     = "Web Application"
  is_default  = false
  resources = [
    digitalocean_app.pathfinder-production.urn,
    digitalocean_database_cluster.pathfinder-production-db-cluster.urn,
  ]
}

resource "digitalocean_vpc" "production-vpc" {
  name        = "production-vpc-network"
  description = "Production VPC network"
  region      = "nyc3"
  ip_range    = "10.10.10.0/24"
}

resource "digitalocean_app" "pathfinder-production" {
  spec {
    name   = "pathfinder-production"
    region = "nyc"

    env {
      key   = "DOMAIN"
      value = "pathfinder-production-cwkio.ondigitalocean.app"
    }

    env {
      key   = "PF__ENVIRONMENT__URL"
      value = "https://pathfinder-production-cwkio.ondigitalocean.app"
    }

    env {
      key   = "APP_PASSWORD"
      value = random_password.setup_password.result
      type  = "SECRET"
    }

    env {
      key   = "PF__PATHFINDER__ALLOW_SETUP"
      value = 0
    }

    env {
      key   = "PF__ENVIRONMENT__DB_PF_HOST"
      value = digitalocean_database_cluster.pathfinder-production-db-cluster.host
    }

    env {
      key   = "PF__ENVIRONMENT__DB_PF_PORT"
      value = digitalocean_database_cluster.pathfinder-production-db-cluster.port
    }

    env {
      key   = "PF__ENVIRONMENT__DB_PF_USER"
      value = digitalocean_database_user.pathfinder-production-user-pathfinder.name
    }

    env {
      key   = "PF__ENVIRONMENT__DB_PF_PASS"
      value = digitalocean_database_user.pathfinder-production-user-pathfinder.password
      type  = "SECRET"
    }

    env {
      key   = "PF__ENVIRONMENT__DB_UNIVERSE_HOST"
      value = digitalocean_database_cluster.pathfinder-production-db-cluster.host
    }

    env {
      key   = "PF__ENVIRONMENT__DB_UNIVERSE_PORT"
      value = digitalocean_database_cluster.pathfinder-production-db-cluster.port
    }

    env {
      key   = "PF__ENVIRONMENT__DB_UNIVERSE_USER"
      value = digitalocean_database_user.pathfinder-production-user-pathfinder.name
    }

    env {
      key   = "PF__ENVIRONMENT__DB_UNIVERSE_PASS"
      value = digitalocean_database_user.pathfinder-production-user-pathfinder.password
      type  = "SECRET"
    }

    env {
      key   = "REDIS_HOST"
      value = "redis"
    }

    env {
      key   = "REDIS_PORT"
      value = "6379"
    }


    env {
      key   = "PF__ENVIRONMENT__REDIS_HOST"
      value = "redis"
    }

    env {
      key   = "PF__ENVIRONMENT__REDIS_PORT"
      value = "6379"
    }

    env {
      key   = "PF__ENVIRONMENT__CCP_SSO_CLIENT_ID"
      value = "3b36fbb1e1d948389fe42b8e84e32d70"
    }

    env {
      key   = "PF__ENVIRONMENT__CCP_SSO_SECRET_KEY"
      value = "wdiBJNgV7NwSTK7vLZjWaCehLW2cmpfEYqr3osWJ"
      type  = "SECRET"
    }

    # env {
    #   key   = "PF__ENVIRONMENT__SOCKET_HOST"
    #   value = "pf-sockets"
    # }

    # env {
    #   key   = "PF__ENVIRONMENT__SOCKET_PORT"
    #   value = "5555"
    # }

    # env {
    #   key   = "PATHFINDER_SOCKET_HOST"
    #   value = "pf-sockets"
    # }

    # env {
    #   key   = "PATHFINDER_SOCKET_PORT"
    #   value = "5555"
    # }

    env {
      key   = "USER"
      value = "pathfinder"
    }

    env {
      key   = "GROUP"
      value = "pathfinder"
    }

    service {
      name               = "pathfinder"
      instance_count     = 1
      instance_size_slug = "professional-xs"

      dockerfile_path = "./pathfinder.Dockerfile"

      http_port = 80

      git {
        repo_clone_url = "https://github.com/ryanrolds/pathfinder-containers.git"
        branch         = "digitalocean_app"
      }
    }

    service {
      name               = "redis"
      instance_count     = 1
      instance_size_slug = "professional-xs"

      http_port      = 8080
      internal_ports = [6379]

      health_check {
        port = 6379
      }

      image {
        registry_type = "DOCKER_HUB"
        registry      = "library"
        repository    = "redis"
        tag           = "latest"
      }
    }

    # service {
    #   name               = "pf-sockets"
    #   instance_count     = 1
    #   instance_size_slug = "professional-xs"

    #   health_check {
    #     port = 8020
    #   }

    #   http_port      = 8080
    #   internal_ports = [5555, 8020]
    #   run_command    = "/usr/local/bin/php cmd.php --tcpHost 0.0.0.0"

    #   dockerfile_path = "./pf-websocket.Dockerfile"

    #   git {
    #     repo_clone_url = "https://github.com/ryanrolds/pathfinder-containers.git"
    #     branch         = "digitalocean_app"
    #   }
    # }

    ingress {
      rule {
        component {
          name = "pathfinder"
        }
        match {
          path {
            prefix = "/"
          }
        }
      }

      rule {
        component {
          name = "redis"
        }
        match {
          path {
            prefix = "/redis"
          }
        }
      }

      # rule {
      #   component {
      #     name = "pf-sockets"
      #   }
      #   match {
      #     path {
      #       prefix = "/sockets"
      #     }
      #   }
      # }
    }
  }
}

resource "digitalocean_database_cluster" "pathfinder-production-db-cluster" {
  name       = "pathfinder-production-db-cluster"
  engine     = "mysql"
  version    = "8"
  size       = "db-s-1vcpu-1gb"
  region     = "nyc3"
  node_count = 1

  lifecycle {
    # do not destoy the DB
    prevent_destroy = true
  }
}

resource "digitalocean_database_db" "pathfinder-production-db-pathfinder" {
  cluster_id = digitalocean_database_cluster.pathfinder-production-db-cluster.id
  name       = "pathfinder"

  lifecycle {
    # do not destoy the DB
    prevent_destroy = true
  }
}

resource "digitalocean_database_db" "pathfinder-production-db-eve-universe" {
  cluster_id = digitalocean_database_cluster.pathfinder-production-db-cluster.id
  name       = "eve_universe"

  lifecycle {
    # do not destoy the DB
    prevent_destroy = true
  }
}

resource "digitalocean_database_user" "pathfinder-production-user-pathfinder" {
  cluster_id        = digitalocean_database_cluster.pathfinder-production-db-cluster.id
  name              = "pathfinder"
  mysql_auth_plugin = "mysql_native_password"
}

resource "digitalocean_database_firewall" "pathfinder-production-db-fw" {
  cluster_id = digitalocean_database_cluster.pathfinder-production-db-cluster.id

  rule {
    type  = "app"
    value = digitalocean_app.pathfinder-production.id
  }
}
