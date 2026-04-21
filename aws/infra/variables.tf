variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "phoenix-starter-kit"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

# --- Database ---

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "phoenix_starter_kit"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "phoenix_starter_kit"
}

variable "db_backup_retention_days" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

# --- Redis (optional) ---

variable "enable_redis" {
  description = "Whether to provision ElastiCache Redis. Disabled by default — enable if your app uses Redis."
  type        = bool
  default     = false
}

variable "redis_node_type" {
  description = "ElastiCache node type (only used when enable_redis = true)"
  type        = string
  default     = "cache.t4g.micro"
}

# --- ECS ---

variable "ecs_cpu" {
  description = "Fargate task CPU units (1024 = 1 vCPU)"
  type        = number
  default     = 512
}

variable "ecs_memory" {
  description = "Fargate task memory in MiB"
  type        = number
  default     = 1024
}

variable "ecs_desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 2
}

variable "container_port" {
  description = "Port the app listens on"
  type        = number
  default     = 8080
}

# --- Autoscaling ---

variable "ecs_min_count" {
  description = "Minimum number of ECS tasks"
  type        = number
  default     = 2
}

variable "ecs_max_count" {
  description = "Maximum number of ECS tasks"
  type        = number
  default     = 6
}

variable "autoscaling_cpu_target" {
  description = "Target CPU utilization percentage for autoscaling"
  type        = number
  default     = 70
}

variable "autoscaling_memory_target" {
  description = "Target memory utilization percentage for autoscaling"
  type        = number
  default     = 80
}

# --- App secrets (set via TF_VAR_ env vars or terraform.tfvars) ---

variable "secret_key_base" {
  description = "Phoenix SECRET_KEY_BASE"
  type        = string
  sensitive   = true
}

variable "peek_api_key" {
  description = "Peek App SDK API key"
  type        = string
  sensitive   = true
}

variable "peek_app_secret" {
  description = "Peek App SDK app secret"
  type        = string
  sensitive   = true
}

variable "peek_app_id" {
  description = "Peek App SDK app ID"
  type        = string
  sensitive   = true
}

variable "posthog_key" {
  description = "PostHog project API key"
  type        = string
  sensitive   = true
}

variable "sentry_dsn" {
  description = "Sentry DSN (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "phx_host" {
  description = "PHX_HOST for the app (your domain)"
  type        = string
  default     = "phoenix-starter-kit.example.com"
}
