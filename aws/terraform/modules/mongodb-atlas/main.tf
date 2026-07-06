# MongoDB Atlas Module
# Creates MongoDB Atlas cluster for production data storage

terraform {
  required_version = ">= 1.5"
  required_providers {
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 1.14"
    }
  }
}

# MongoDB Atlas Project
resource "mongodbatlas_project" "main" {
  name   = "${var.environment}-project"
  org_id = var.mongodb_org_id

  lifecycle {
    ignore_changes = [teams]
  }
}

# MongoDB Atlas Cluster
resource "mongodbatlas_cluster" "main" {
  project_id = mongodbatlas_project.main.id
  name       = "${var.environment}-cluster"

  provider_name               = var.cloud_provider
  provider_instance_size_name = var.instance_size_name
  provider_region_name        = var.mongodb_region

  # Backup configuration
  backup_enabled = var.backup_enabled
  pit_enabled    = var.pit_enabled

  # Performance settings
  auto_scaling_disk_gb_enabled = var.auto_scaling_disk_gb
  disk_size_gb                 = var.disk_size_gb

  # Monitoring
  mongo_db_major_version = var.mongodb_major_version

  lifecycle {
    ignore_changes = [disk_size_gb]
  }

  depends_on = [
    mongodbatlas_project.main,
    mongodbatlas_project_ip_access_list.aws_vpc
  ]
}

# IP Whitelist for VPC
resource "mongodbatlas_project_ip_access_list" "aws_vpc" {
  project_id = mongodbatlas_project.main.id
  cidr_block = var.vpc_cidr
  comment    = var.ip_whitelist_comment
}

# Database User
resource "mongodbatlas_database_user" "app" {
  project_id         = mongodbatlas_project.main.id
  auth_database_name = var.auth_database_name
  username           = var.database_username
  password           = var.database_password

  roles {
    role_name     = var.database_role
    database_name = var.auth_database_name
  }

  scopes {
    name = mongodbatlas_cluster.main.name
    type = var.scope_type
  }

  depends_on = [mongodbatlas_cluster.main]
}

# Private Endpoint for AWS VPC (optional, for enhanced security)
resource "mongodbatlas_privatelink_endpoint" "aws" {
  count         = var.enable_private_endpoint ? 1 : 0
  project_id    = mongodbatlas_project.main.id
  provider_name = var.cloud_provider
  region        = var.mongodb_region

  depends_on = [mongodbatlas_project.main]
}
