terraform {
  backend "s3" {
    bucket         = "de-c1w2-824491982692-us-east-1-terraform-state"
    key            = "de-c1w2/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}
