terraform {
  backend "s3" {
    bucket         = "unique-s3-bucket-name"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    workspace_key_prefix = "workspace-prefix"
  }
}
