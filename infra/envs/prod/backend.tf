terraform {
  backend "s3" {
    bucket         = "hotel-booking-tfstate-prod"
    key            = "prod/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "hotel-booking-tfstate-lock-prod"
    encrypt        = true
  }
}
