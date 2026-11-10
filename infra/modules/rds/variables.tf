variable "name" {
  description = "Name prefix applied to all database resources."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the DB subnet group."
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group attached to the database instance."
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL engine version."
  type        = string
}

variable "parameter_group_family" {
  description = "DB parameter group family matching the engine version."
  type        = string
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "allocated_storage" {
  description = "Initial storage in GiB."
  type        = number
}

variable "max_allocated_storage" {
  description = "Upper bound for storage autoscaling in GiB."
  type        = number
}

variable "db_name" {
  description = "Name of the initial database."
  type        = string
}

variable "master_username" {
  description = "Master username. The password is generated and stored in Secrets Manager."
  type        = string
}

variable "port" {
  description = "Database port."
  type        = number
  default     = 5432
}

variable "multi_az" {
  description = "Deploy a standby replica in a second availability zone."
  type        = bool
}

variable "backup_retention_period" {
  description = "Days to keep automated backups."
  type        = number

  validation {
    condition     = var.backup_retention_period >= 1 && var.backup_retention_period <= 35
    error_message = "backup_retention_period must be between 1 and 35 days."
  }
}

variable "deletion_protection" {
  description = "Block deletion of the instance through the API."
  type        = bool
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot when the instance is destroyed."
  type        = bool
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights."
  type        = bool
  default     = false
}

variable "apply_immediately" {
  description = "Apply modifications immediately instead of in the next maintenance window."
  type        = bool
  default     = false
}
