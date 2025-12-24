variable "aws_account_id" {
  type        = string
  description = "AWS account ID"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "github_owner" {
  type        = string
  description = "GitHub org/user that owns the repo"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name"
}

variable "developer_user_name" {
  type        = string
  description = "Local IAM user name for EKS access"
}

variable "k8s_cluster_name" {
  type        = string
  description = "EKS cluster name"
  default     = "stackgen-eks"
}

variable "k8s_namespace" {
  type        = string
  description = "Default Kubernetes namespace"
  default     = "stackgen"
}

