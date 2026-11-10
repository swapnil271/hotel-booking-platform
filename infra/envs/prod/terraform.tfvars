project     = "hotel-booking"
environment = "prod"
aws_region  = "ap-south-1"

vpc_cidr             = "10.20.0.0/16"
availability_zones   = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
public_subnet_cidrs  = ["10.20.0.0/24", "10.20.1.0/24", "10.20.2.0/24"]
private_subnet_cidrs = ["10.20.10.0/24", "10.20.11.0/24", "10.20.12.0/24"]
single_nat_gateway   = false

container_image         = "nginxinc/nginx-unprivileged:1.27-alpine"
container_port          = 8080
task_cpu                = 1024
task_memory             = 2048
desired_count           = 3
min_capacity            = 3
max_capacity            = 10
certificate_arn         = "arn:aws:acm:ap-south-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
alb_deletion_protection = true
log_retention_days      = 90

db_engine_version               = "16.4"
db_parameter_group_family       = "postgres16"
db_instance_class               = "db.r6g.large"
db_allocated_storage            = 100
db_max_allocated_storage        = 500
db_name                         = "hotel"
db_master_username              = "hotel_admin"
db_multi_az                     = true
db_backup_retention_period      = 14
db_deletion_protection          = true
db_skip_final_snapshot          = false
db_performance_insights_enabled = true
db_apply_immediately            = false
