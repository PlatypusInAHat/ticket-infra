variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name used in resource names and tags"
  type        = string
  default     = "trial"
}

variable "project_name" {
  description = "Project tag"
  type        = string
  default     = "TicketBooking"
}

variable "instance_type" {
  description = "Graviton instance type; 4 GiB is enough for 6 services, 5 MongoDB and RabbitMQ at trial load"
  type        = string
  default     = "t4g.medium"
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size (holds Docker images and MongoDB/RabbitMQ volumes)"
  type        = number
  default     = 30
}

variable "app_repo_url" {
  description = "HTTPS clone URL of the app repository (the one containing docker-compose.yml)"
  type        = string
}

variable "app_repo_ref" {
  description = "Branch or tag to deploy"
  type        = string
  default     = "dev"
}

variable "app_env_parameter" {
  description = "SSM SecureString holding the .env file for docker compose (see compose.env.example)"
  type        = string
  default     = "/ticketstage/trial/compose-env"
}

variable "tunnel_token_parameter" {
  description = "SSM SecureString holding the Cloudflare Tunnel token"
  type        = string
  default     = "/ticketstage/trial/cloudflare-tunnel-token"
}

variable "git_token_parameter" {
  description = "Optional SSM SecureString with a read-only GitHub token for a private app repo; empty for a public repo"
  type        = string
  default     = ""
}

variable "docker_compose_version" {
  description = "Docker Compose plugin release"
  type        = string
  default     = "v2.29.7"
}

variable "cloudflared_version" {
  description = "cloudflare/cloudflared image tag"
  type        = string
  default     = "2024.12.2"
}
