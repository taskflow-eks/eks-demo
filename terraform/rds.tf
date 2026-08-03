############################################
# RDS PostgreSQL + Secrets Manager
#  - 프라이빗 서브넷에만 배치하고 외부에서 직접 접근할 수 없도록 구성
#  - 접속 정보는 코드에 두지 않고 Secrets Manager에 저장
#    (backend/app.py 가 DB_SECRET_NAME 으로 읽어감)
############################################

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "RDS PostgreSQL"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# EKS 워커 노드에서 오는 접속만 허용
resource "aws_vpc_security_group_ingress_rule" "rds_from_nodes" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = module.eks.node_security_group_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

# Bastion에서 오는 접속 허용 (psql 로 직접 확인할 때 사용)
resource "aws_vpc_security_group_ingress_rule" "rds_from_bastion" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.bastion.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

resource "random_password" "db" {
  length  = 24
  special = true
  # RDS가 허용하지 않는 문자 제외
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_instance" "this" {
  identifier = "${var.project_name}-db"

  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = var.db_multi_az

  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false

  performance_insights_enabled = false
  apply_immediately            = true
}

# app.py의 get_db_credentials()가 기대하는 키 구조로 저장
resource "aws_secretsmanager_secret" "db" {
  name                    = var.db_secret_name
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    host     = aws_db_instance.this.address
    port     = tostring(aws_db_instance.this.port)
    dbname   = var.db_name
    username = var.db_username
    password = random_password.db.result
  })
}
