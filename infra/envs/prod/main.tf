locals {
  name = "${var.project}-${var.environment}"

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "network" {
  source = "../../modules/network"

  name                 = local.name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  single_nat_gateway   = var.single_nat_gateway
  container_port       = var.container_port
  enable_https         = var.certificate_arn != ""
}

module "rds" {
  source = "../../modules/rds"

  name                         = local.name
  subnet_ids                   = module.network.private_subnet_ids
  security_group_id            = module.network.rds_security_group_id
  engine_version               = var.db_engine_version
  parameter_group_family       = var.db_parameter_group_family
  instance_class               = var.db_instance_class
  allocated_storage            = var.db_allocated_storage
  max_allocated_storage        = var.db_max_allocated_storage
  db_name                      = var.db_name
  master_username              = var.db_master_username
  multi_az                     = var.db_multi_az
  backup_retention_period      = var.db_backup_retention_period
  deletion_protection          = var.db_deletion_protection
  skip_final_snapshot          = var.db_skip_final_snapshot
  performance_insights_enabled = var.db_performance_insights_enabled
  apply_immediately            = var.db_apply_immediately
}

module "ecs" {
  source = "../../modules/ecs"

  name                    = local.name
  aws_region              = var.aws_region
  vpc_id                  = module.network.vpc_id
  public_subnet_ids       = module.network.public_subnet_ids
  private_subnet_ids      = module.network.private_subnet_ids
  alb_security_group_id   = module.network.alb_security_group_id
  ecs_security_group_id   = module.network.ecs_security_group_id
  container_image         = var.container_image
  container_port          = var.container_port
  task_cpu                = var.task_cpu
  task_memory             = var.task_memory
  desired_count           = var.desired_count
  min_capacity            = var.min_capacity
  max_capacity            = var.max_capacity
  certificate_arn         = var.certificate_arn
  alb_deletion_protection = var.alb_deletion_protection
  log_retention_days      = var.log_retention_days
  db_host                 = module.rds.address
  db_port                 = module.rds.port
  db_name                 = module.rds.db_name
  db_secret_arn           = module.rds.master_user_secret_arn
}
