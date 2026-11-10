terraform {
  backend "s3" {
    bucket         = "hotel-booking-tfstate-dev"
    key            = "dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "hotel-booking-tfstate-lock-dev"
    encrypt        = true
  }
}
