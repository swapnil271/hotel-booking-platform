variable "project" {
  description = "Project name used as a prefix for resource names."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "aws_region" {
  description = "AWS region."
  type        = string
}

variable "plan_only" {
  description = "Skip AWS credential checks so the configuration can be planned offline."
  type        = bool
  default     = false
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
}

variable "availability_zones" {
  description = "Availability zones used for the subnets."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets."
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Share one NAT gateway across availability zones."
  type        = bool
}

variable "container_image" {
  description = "Container image run by the ECS service."
  type        = string
}

variable "container_port" {
  description = "Port the container listens on."
  type        = number
}

variable "task_cpu" {
  description = "Fargate task CPU units."
  type        = number
}

variable "task_memory" {
  description = "Fargate task memory in MiB."
  type        = number
}

variable "desired_count" {
  description = "Initial number of running tasks."
  type        = number
}

variable "min_capacity" {
  description = "Minimum task count for autoscaling."
  type        = number
}

variable "max_capacity" {
  description = "Maximum task count for autoscaling."
  type        = number
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS. Empty serves HTTP only."
  type        = string
}

variable "alb_deletion_protection" {
  description = "Block deletion of the load balancer."
  type        = bool
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
}

variable "db_engine_version" {
  description = "PostgreSQL engine version."
  type        = string
}

variable "db_parameter_group_family" {
  description = "DB parameter group family."
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "db_allocated_storage" {
  description = "Initial database storage in GiB."
  type        = number
}

variable "db_max_allocated_storage" {
  description = "Storage autoscaling ceiling in GiB."
  type        = number
}

variable "db_name" {
  description = "Name of the initial database."
  type        = string
}

variable "db_master_username" {
  description = "Database master username."
  type        = string
}

variable "db_multi_az" {
  description = "Run the database in multiple availability zones."
  type        = bool
}

variable "db_backup_retention_period" {
  description = "Days to keep automated database backups."
  type        = number
}

variable "db_deletion_protection" {
  description = "Block deletion of the database instance."
  type        = bool
}

variable "db_skip_final_snapshot" {
  description = "Skip the final snapshot on destroy."
  type        = bool
}

variable "db_performance_insights_enabled" {
  description = "Enable Performance Insights."
  type        = bool
}

variable "db_apply_immediately" {
  description = "Apply database modifications immediately."
  type        = bool
}
