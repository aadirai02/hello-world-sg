module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.0"

  # Name the VPC after the cluster
  name = var.k8s_cluster_name

  cidr = "10.0.0.0/16"

  # Use the same region as aws_region
  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

