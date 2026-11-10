variable "name" {
  description = "Name prefix applied to all network resources."
  type        = string
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
  description = "CIDR blocks of the public subnets, one per availability zone."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets, one per availability zone."
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway instead of one per availability zone."
  type        = bool
  default     = true
}

variable "container_port" {
  description = "Port the application container listens on."
  type        = number
}

variable "db_port" {
  description = "Port the database listens on."
  type        = number
  default     = 5432
}

variable "alb_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the load balancer."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_https" {
  description = "Open port 443 on the load balancer security group."
  type        = bool
  default     = false
}
