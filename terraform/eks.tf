module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.4"

  cluster_name    = var.k8s_cluster_name
  cluster_version = "1.33"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  eks_managed_node_groups = {
    hello-world-ng = {
      desired_size   = 1
      min_size       = 1
      max_size       = 2
      instance_types = ["t3.medium"]
      subnet_ids     = module.vpc.private_subnets
    }
  }

  cluster_addons = {
    vpc-cni   = { most_recent = true }
    kube-proxy = { most_recent = true }
    coredns   = { most_recent = true }

    aws-ebs-csi-driver = {
      most_recent            = true
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
    }
  }

  enable_irsa = true

  access_entries = {
    aaditya = {
      principal_arn = "arn:aws:iam::${var.aws_account_id}:user/${var.developer_user_name}"

      policy_associations = {
        cluster_admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
    github_actions = {
      principal_arn = aws_iam_role.github_actions.arn

      policy_associations = {
        cluster_admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }
}

