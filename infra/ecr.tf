# One private registry per image. force_delete lets `terraform destroy` remove
# repositories that still contain images.

resource "aws_ecr_repository" "app" {
  for_each     = toset(["backend", "frontend"])
  name         = "${var.project}-${each.key}"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Keep only the 10 most recent images per repository.
resource "aws_ecr_lifecycle_policy" "app" {
  for_each   = aws_ecr_repository.app
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
