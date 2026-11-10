variable "name" {
  description = "Name prefix applied to all ECS and load balancer resources."
  type        = string
}

variable "aws_region" {
  description = "AWS region used for the log configuration."
  type        = string
}

variable "vpc_id" {
  description = "VPC that hosts the target group."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets for the load balancer."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnets for the Fargate tasks."
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group attached to the load balancer."
  type        = string
}

variable "ecs_security_group_id" {
  description = "Security group attached to the Fargate tasks."
  type        = string
}

variable "container_image" {
  description = "Container image run by the service."
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

variable "health_check_path" {
  description = "HTTP path used by the target group health check."
  type        = string
  default     = "/"
}

variable "certificate_arn" {
  description = "ACM certificate ARN. When empty the load balancer serves plain HTTP only."
  type        = string
  default     = ""
}

variable "alb_deletion_protection" {
  description = "Block deletion of the load balancer."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
}

variable "db_host" {
  description = "Database hostname passed to the container."
  type        = string
}

variable "db_port" {
  description = "Database port passed to the container."
  type        = number
}

variable "db_name" {
  description = "Database name passed to the container."
  type        = string
}

variable "db_secret_arn" {
  description = "Secrets Manager secret holding the database credentials."
  type        = string
}
