# --- Application Load Balancer ---
#
# Cloudflare handles SSL termination and caching.
# Traffic flow: Client → Cloudflare (HTTPS) → ALB (HTTPS) → ECS
#
# Cloudflare DNS: CNAME your domain to the ALB DNS name (output: alb_dns_name)
# Cloudflare SSL mode: set to "Full" — Cloudflare connects to the ALB over HTTPS (port 443).

resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = { Name = "${local.name_prefix}-alb" }
}

resource "aws_lb_target_group" "app" {
  name        = "${local.name_prefix}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = { Name = "${local.name_prefix}-tg" }
}

# ACM certificate for HTTPS — DNS validation via Cloudflare (manual step required).
# After `terraform apply` blocks on aws_acm_certificate_validation, run:
#   terraform output acm_certificate_validation_records
# Add the CNAME to Cloudflare (DNS-only / grey-cloud, NOT proxied). Validates in ~2-5 min.
resource "aws_acm_certificate" "main" {
  domain_name       = var.phx_host
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${local.name_prefix}-cert" }
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn = aws_acm_certificate.main.arn
  # No validation_record_fqdns — DNS is in Cloudflare, not Route 53.
  # Terraform blocks here until ACM reports the cert as ISSUED.
}

# HTTP listener — redirects to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS listener — Cloudflare connects here in "Full" mode
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.main.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
