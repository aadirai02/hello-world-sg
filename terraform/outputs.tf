output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded CA data for the EKS cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "ecr_repository_url" {
  description = "ECR repository URL for hello-world app"
  value       = aws_ecr_repository.app.repository_url
}

output "update_kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
