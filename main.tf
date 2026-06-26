# Amazon Linux 2023 の最新AMIの取得
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "terraform-shin-vpc"
  }
}

# Publc Subnet 1a
resource "aws_subnet" "public_1a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "pubric-subnet-1a"
  }
}

# Public Subnet 1c
resource "aws_subnet" "public_1c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1c"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "terraform-shin-igw"
  }
}

# Route Table
resource "aws_route_table" "public_shin_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-shin-rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "public_1a_assoc" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public_shin_rt.id
}

resource "aws_route_table_association" "public_1c_assoc" {
  subnet_id      = aws_subnet.public_1c.id
  route_table_id = aws_route_table.public_shin_rt.id
}

# ALB用Security Group
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP access to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP from ALB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

　egress {
   description = "Allow HTTP all outbound traffic
   from_port = 0
   to_port = 0
   protcol = "-1"
   cidr_blocks ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

# EC2用Security Group
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg"
  description = "Allow HTTP from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow HTTP from ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-sg"
  }
}

# EC 1台目
resource "aws_instance" "web_1a" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_1a.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm_profile.name

  user_data = <<EOF
#!/bin/bash
dnf update -y
dnf install httpd -y
systemctl enable httpd
systemctl start httpd
echo "<h1>Hello from EC2-1a</h1>" > /var/www/html/index.html
EOF

  tags = {
    Name = "web-1a"
  }
}

# EC 2台目
resource "aws_instance" "web_1c" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_1c.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm_profile.name

  user_data = <<EOF
#!/bin/bash
dnf update -y
dnf install httpd -y
systemctl enable httpd
systemctl start httpd
echo "<h1>Hello from EC2-1c</h1>" > /var/www/html/index.html
EOF

  tags = {
    Name = "web-1c"
  }
}

# SSM用IAM Role
resource "aws_iam_role" "ec2_ssm_role" {
  name = "terraform-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# SSM管理ポリシー付与
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance Profile
resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "terraform-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

# S3 Bucket
resource "aws_s3_bucket" "ssm_log_bucket" {
  bucket = var.bucket_name

  tags = {
    Name = "ssm-log-bucket"
  }
}

# SSM document
resource "aws_ssm_document" "session_manager_preferances" {
  name          = "SSM-SessionManagerRunShell"
  document_type = "Session"

  content = jsonencode({
    schemaVersion = "1.0"
    description   = "Session Manager preferances"

    sessionType = "Standard_Stream"

    inputs = {
      s3BucketName        = aws_s3_bucket.ssm_log_bucket.bucket
      s3KeyPrefix         = "ssm-log"
      s3EncryptionEnabled = true
    }
  })
}

# SSMログ用S3権限
resource "aws_iam_role_policy" "ec2_s3_logging" {
  name = "ec2-ssm-s3-logging-policy"
  role = aws_iam_role.ec2_ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetEncryptionConfiguration"
        ]
        Resource = [
          "${aws_s3_bucket.ssm_log_bucket.arn}/ssmlogs/*",
          aws_s3_bucket.ssm_log_bucket.arn
        ]
      }
    ]
  })
}

# ALB
resource "aws_lb" "app_alb" {
  name               = "terraform-shin-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets = [
    aws_subnet.public_1a.id,
    aws_subnet.public_1c.id
  ]

  tags = {
    Name = "terraform-shin-alb"
  }
}
# Target Group
resource "aws_lb_target_group" "web_tg" {
  name     = "terraform-shin-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "terraform-shin-tg"
  }
}

# EC2をTarget Groupへ登録
resource "aws_lb_target_group_attachment" "web_1a" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web_1a.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "web_1c" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web_1c.id
  port             = 80
}

# Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}
