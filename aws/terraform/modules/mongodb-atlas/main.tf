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

  is_collect_database_specific_stats_enabled = var.enable_database_stats
  is_data_explorer_enabled                   = var.enable_data_explorer
  is_extended_storage_sizes_enabled          = var.enable_extended_storage
  is_performance_advisor_enabled             = var.enable_performance_advisor
  is_realtime_performance_panel_enabled      = var.enable_realtime_performance
  is_schema_advisor_enabled                  = var.enable_schema_advisor

  lifecycle {
    ignore_changes = [teams]
  }
}

# MongoDB Atlas Cluster
resource "mongodbatlas_cluster" "main" {
  project_id = mongodbatlas_project.main.id
  name       = "${var.environment}-cluster"
  version    = var.mongodb_version

  provider_name               = var.cloud_provider
  provider_instance_size_name = var.instance_size_name
  provider_region_name        = var.mongodb_region

  # Backup configuration
  backup_enabled = var.backup_enabled
  backup_type    = var.backup_type
  pit_enabled    = var.pit_enabled

  # Performance settings
  auto_scaling_disk_gb_enabled = var.auto_scaling_disk_gb
  disk_size_gb                 = var.disk_size_gb
  performance_insights_enabled = var.enable_performance_insights

  # Monitoring
  mongo_db_major_version = var.mongodb_major_version

  # Tag for management
  tags = {
    Environment = var.environment
    Application = var.application_name
  }

  lifecycle {
    ignore_changes = [disk_size_gb]
  }

  depends_on = [
    mongodbatlas_project.main,
    mongodbatlas_project_ip_whitelist.aws_vpc
  ]
}

# IP Whitelist for VPC
resource "mongodbatlas_project_ip_whitelist" "aws_vpc" {
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

# Connection String Secret (will be stored in AWS Secrets Manager)
resource "mongodbatlas_cluster_outage_simulation" "test" {
  count        = var.enable_outage_test ? 1 : 0
  project_id   = mongodbatlas_project.main.id
  cluster_name = mongodbatlas_cluster.main.name
}

# Private Endpoint for AWS VPC (optional, for enhanced security)
resource "mongodbatlas_privatelink_endpoint" "aws" {
  count         = var.enable_private_endpoint ? 1 : 0
  project_id    = mongodbatlas_project.main.id
  provider_name = var.cloud_provider
  region        = var.mongodb_region

  depends_on = [mongodbatlas_project.main]
}
