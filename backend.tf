terraform {
  backend "s3" {
    bucket  = "emr-demo-state-zxcvzxcv23"
    key     = "ec2ansible/terraform.tfstate"
    region  = "us-east-2"
    encrypt = true
  }
}
