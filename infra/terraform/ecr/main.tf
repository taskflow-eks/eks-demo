############################################################
# ECR
#  - GitHub Actions가 빌드한 이미지를 push하는 레포지토리
#  - 레포 이름은 k8s 매니페스트의 image 경로와 반드시 일치해야 함
############################################################

resource "aws_ecr_repository" "this" {
  for_each = toset(var.repositories)

  name                 = each.value
  image_tag_mutability = "MUTABLE"

  # 이미지가 남아 있으면 레포지토리 삭제가 실패하므로,
  # 실습 환경에서는 함께 삭제되도록 허용한다
  force_delete = var.force_delete

  image_scanning_configuration {
    scan_on_push = true
  }
}

# 오래된 이미지가 무한히 쌓이지 않도록 최근 N개만 유지
resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "최근 ${var.keep_image_count}개 이미지만 보관"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.keep_image_count
      }
      action = {
        type = "expire"
      }
    }]
  })
}
