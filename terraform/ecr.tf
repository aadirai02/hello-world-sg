resource "aws_ecr_repository" "app" {
  name                 = "hello-world"
  image_tag_mutability = "MUTABLE"
}

