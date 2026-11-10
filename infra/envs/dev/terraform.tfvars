project     = "hotel-booking"
environment = "dev"
aws_region  = "ap-south-1"

vpc_cidr             = "10.10.0.0/16"
availability_zones   = ["ap-south-1a", "ap-south-1b"]
public_subnet_cidrs  = ["10.10.0.0/24", "10.10.1.0/24"]
private_subnet_cidrs = ["10.10.10.0/24", "10.10.11.0/24"]
single_nat_gateway   = true

container_image         = "nginxinc/nginx-unprivileged:1.27-alpine"
container_port          = 8080
task_cpu                = 256
task_memory             = 512
desired_count           = 1
min_capacity            = 1
max_capacity            = 2
certificate_arn         = ""
alb_deletion_protection = false
log_retention_days      = 7

db_engine_version               = "16.4"
db_parameter_group_family       = "postgres16"
db_instance_class               = "db.t4g.micro"
db_allocated_storage            = 20
db_max_allocated_storage        = 50
db_name                         = "hotel"
db_master_username              = "hotel_admin"
db_multi_az                     = false
db_backup_retention_period      = 3
db_deletion_protection          = false
db_skip_final_snapshot          = true
db_performance_insights_enabled = false
db_apply_immediately            = true
