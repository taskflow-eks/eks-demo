############################################
# Bastion
#  - 퍼블릭 서브넷에 두고, 프라이빗 리소스(RDS, 워커 노드)에 접근할 때 경유
#  - 키페어 없이 SSM Session Manager로도 접속 가능
############################################

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "Bastion host"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "${var.project_name}-bastion-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  security_group_id = aws_security_group.bastion.id
  cidr_ipv4         = var.allowed_ssh_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "bastion_all" {
  security_group_id = aws_security_group.bastion.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_iam_role" "bastion" {
  name = "${var.project_name}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.project_name}-bastion-profile"
  role = aws_iam_role.bastion.name
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = "t3.micro"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  associate_public_ip_address = true
  key_name                    = var.bastion_key_name != "" ? var.bastion_key_name : null

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y postgresql15 git
    curl -sLO "https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  EOF

  tags = {
    Name = "${var.project_name}-bastion"
  }
}
