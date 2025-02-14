terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.78.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

##############################
# VPC 與網路相關資源
##############################

# VPC
resource "aws_vpc" "vpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "igw"
  }
}

##############################
# 公有子網 (用於 ALB 與 NAT Gateway)
##############################

resource "aws_subnet" "public_subnet1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "192.168.10.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public_subnet1"
  }
}

resource "aws_subnet" "public_subnet2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "192.168.11.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "public_subnet2"
  }
}

# 公有路由表（透過 IGW 連接外網）
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  
  tags = {
    Name = "public"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_subnet2.id
  route_table_id = aws_route_table.public.id
}

##############################
# NAT Gateway 與私有子網資源
##############################

# 為 NAT Gateway 配置彈性 IP
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  depends_on = [aws_internet_gateway.igw]
}

# NAT Gateway 部署在公有子網1
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet1.id

  tags = {
    Name = "nat-gateway"
  }
}

# 私有子網 (用於 Auto Scaling Group 中的 EC2 實例)
resource "aws_subnet" "private_subnet1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "192.168.20.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "private_subnet1"
  }
}

resource "aws_subnet" "private_subnet2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "192.168.21.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = false

  tags = {
    Name = "private_subnet2"
  }
}

# 私有路由表：所有流量透過 NAT Gateway 出網
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_subnet1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_subnet2.id
  route_table_id = aws_route_table.private.id
}

##############################
# 安全群組設定
##############################

# 用於 EC2 實例 (容器) 的安全群組
resource "aws_security_group" "sg1" {
  vpc_id = aws_vpc.vpc.id
  name   = "web-sg"

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow 5000"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-sg"
  }
}

# ALB 專用安全群組
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.vpc.id
  name   = "alb_sg"

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow traffic from ALB to port 5000"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb_sg"
  }
}

##############################
# ALB 與相關資源
##############################

# Application Load Balancer 部署於公有子網中
resource "aws_lb" "alb" {
  name               = "alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id]
  
  tags = {
    Name = "alb"
  }
}

# Target Group：將 ALB 請求轉發到後端實例的 5000 port
resource "aws_lb_target_group" "tg" {
  name        = "tg"
  port        = 5000
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.vpc.id

  health_check {
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    interval            = 15
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 5
    matcher             = "200"
  }
  
  tags = {
    Name = "tg"
  }
}

# HTTP Listener
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
  
  tags = {
    Name = "listener"
  }
}

# HTTPS Listener
resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = "arn:aws:acm:ap-northeast-1:490004624266:certificate/554c8dfa-996e-4a27-9e3b-dcb058e20583"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
  
  tags = {
    Name = "https_listener"
  }
}

# Route53 DNS 記錄 (假設您已在 Route53 中擁有該 zone)
resource "aws_route53_record" "alb" {
  zone_id = "Z05281272J1GJUDK0ECY9"
  name    = "www.leeway.live"
  type    = "A"
  
  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}

##############################
# Launch Template 與 Auto Scaling Group (私有子網)
##############################

resource "aws_launch_template" "web_t" {
  name_prefix   = "web1-t"
  image_id      = "ami-0ff64d0fda39b42ce"  # 請確認此 AMI 為您所需映像
  instance_type = "t2.micro"
  key_name      = "li2-key"

  iam_instance_profile {
    name = "ECRAccessRole"
  }

  network_interfaces {
    security_groups             = [aws_security_group.sg1.id]
    associate_public_ip_address = false
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ec2-auto"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg" {
  desired_capacity         = 2
  max_size                 = 5
  min_size                 = 2

  launch_template {
    id      = aws_launch_template.web_t.id
    version = "$Latest"
  }

  # 使用私有子網 (透過 NAT 存取外部網路)
  vpc_zone_identifier      = [aws_subnet.private_subnet1.id, aws_subnet.private_subnet2.id]
  health_check_type        = "ELB"
  health_check_grace_period = 30

  tag {
    key                 = "Name"
    value               = "ec2-web"
    propagate_at_launch = true
  }
  tag {
    key                 = "Environment"
    value               = "prod"
    propagate_at_launch = true
  }

  target_group_arns = [aws_lb_target_group.tg.arn]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "scale_out_policy" {
  name                   = "scale_out"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

resource "aws_autoscaling_policy" "scale_in_policy" {
  name                   = "scale_in"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

resource "aws_cloudwatch_metric_alarm" "alb_request_count_high" {
  alarm_name          = "alb_request_count_high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RequestCountPerTarget"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 2
  alarm_description   = "Alarm when ALB request count exceeds 2"
  dimensions = {
    TargetGroup  = aws_lb_target_group.tg.arn_suffix
    LoadBalancer = aws_lb.alb.arn_suffix
  }
  alarm_actions = [aws_autoscaling_policy.scale_out_policy.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_request_count_low" {
  alarm_name          = "alb_request_count_low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RequestCountPerTarget"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 2
  alarm_description   = "Alarm when ALB request count falls below 2"
  dimensions = {
    TargetGroup  = aws_lb_target_group.tg.arn_suffix
    LoadBalancer = aws_lb.alb.arn_suffix
  }
  alarm_actions = [aws_autoscaling_policy.scale_in_policy.arn]
}

resource "aws_autoscaling_lifecycle_hook" "autoscaling_lifecycle_hook" {
  name                   = "autoscaling_lifecycle_hook"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_LAUNCHING"
  default_result         = "CONTINUE"
  heartbeat_timeout      = 120
}
