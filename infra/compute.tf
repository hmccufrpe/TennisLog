# Application hosts (one per AZ) behind an Application Load Balancer.

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "app" {
  count                       = var.instance_count
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[count.index % 2].id
  vpc_security_group_ids      = [aws_security_group.app.id]
  iam_instance_profile        = local.instance_profile_name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    region            = var.aws_region
    registry          = split("/", aws_ecr_repository.app["backend"].repository_url)[0]
    backend_image     = aws_ecr_repository.app["backend"].repository_url
    frontend_image    = aws_ecr_repository.app["frontend"].repository_url
    db_host           = aws_db_instance.main.address
    db_name           = var.db_name
    db_user           = var.db_username
    db_password_param = aws_ssm_parameter.db_password.name
  })
  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  # A newer AMI must not force-replace running hosts.
  lifecycle {
    ignore_changes = [ami]
  }

  tags = { Name = "${var.project}-app-${count.index + 1}" }
}

resource "aws_lb" "main" {
  name               = "${var.project}-alb"
  load_balancer_type = "application"
  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.alb.id]
}

# Health check goes through nginx: /api/health -> backend /health (which also checks the DB).
resource "aws_lb_target_group" "app" {
  name                 = "${var.project}-tg"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = aws_vpc.main.id
  deregistration_delay = 10

  health_check {
    path                = "/api/health"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group_attachment" "app" {
  count            = var.instance_count
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app[count.index].id
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
