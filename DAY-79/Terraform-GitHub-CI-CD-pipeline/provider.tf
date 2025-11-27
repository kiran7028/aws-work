terraform {
  backend "s3" {
    bucket         = "terraform-bucket-state-aws"
    key            = "project1/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-lock-table"
    encrypt        = true
  }
}