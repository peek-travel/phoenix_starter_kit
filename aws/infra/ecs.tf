# --- ECS Cluster + Service ---

resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "${local.name_prefix}-cluster" }
}

# IAM role for ECS task execution (pulling images, writing logs)
resource "aws_iam_role" "ecs_execution" {
  name = "${local.name_prefix}-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow ECS to read SSM parameters (for secrets)
resource "aws_iam_role_policy" "ecs_ssm" {
  name = "${local.name_prefix}-ecs-ssm"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter"
        ]
        Resource = concat(
          [
            aws_ssm_parameter.database_url.arn,
            aws_ssm_parameter.secret_key_base.arn,
            aws_ssm_parameter.peek_api_key.arn,
            aws_ssm_parameter.peek_app_secret.arn,
            aws_ssm_parameter.peek_app_id.arn,
            aws_ssm_parameter.posthog_key.arn,
            aws_ssm_parameter.sentry_dsn.arn,
          ]
        )
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = "arn:aws:kms:${var.aws_region}:*:key/aws/ssm"
      }
    ]
  })
}

# Allow ECS Exec (SSM Session Manager) on running tasks
resource "aws_iam_role_policy" "ecs_exec" {
  name = "${local.name_prefix}-ecs-exec"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM role for the running task itself
resource "aws_iam_role" "ecs_task" {
  name = "${local.name_prefix}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# CloudWatch log group
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = 30

  tags = { Name = "${local.name_prefix}-logs" }
}

# --- Task Definition ---

resource "aws_ecs_task_definition" "app" {
  family                   = "${local.name_prefix}-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_cpu
  memory                   = var.ecs_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = concat(
        [
          { name = "PHX_HOST", value = var.phx_host },
          { name = "PHX_SERVER", value = "true" },
          { name = "PORT", value = tostring(var.container_port) },
          { name = "POOL_SIZE", value = "10" },
          { name = "MIX_ENV", value = "prod" },
          { name = "SENTRY_ENVIRONMENT", value = var.environment },
        ],
        var.enable_redis ? [
          { name = "REDIS_URL", value = "redis://${aws_elasticache_cluster.main[0].cache_nodes[0].address}:6379" }
        ] : []
      )

      secrets = [
        {
          name      = "DATABASE_URL"
          valueFrom = aws_ssm_parameter.database_url.arn
        },
        {
          name      = "SECRET_KEY_BASE"
          valueFrom = aws_ssm_parameter.secret_key_base.arn
        },
        {
          name      = "PEEK_API_KEY"
          valueFrom = aws_ssm_parameter.peek_api_key.arn
        },
        {
          name      = "PEEK_APP_SECRET"
          valueFrom = aws_ssm_parameter.peek_app_secret.arn
        },
        {
          name      = "PEEK_APP_ID"
          valueFrom = aws_ssm_parameter.peek_app_id.arn
        },
        {
          name      = "POSTHOG_KEY"
          valueFrom = aws_ssm_parameter.posthog_key.arn
        },
        {
          name      = "SENTRY_DSN"
          valueFrom = aws_ssm_parameter.sentry_dsn.arn
        },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "app"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])
}

# --- ECS Service ---

resource "aws_ecs_service" "app" {
  name                   = "${local.name_prefix}-app"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.app.arn
  desired_count          = var.ecs_desired_count
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  depends_on = concat(
    [aws_lb_listener.http, aws_lb_listener.https],
    var.enable_redis ? [aws_elasticache_cluster.main[0]] : []
  )

  lifecycle {
    ignore_changes = [task_definition]
  }
}

# --- Autoscaling ---

resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.ecs_max_count
  min_capacity       = var.ecs_min_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Scale on CPU utilization
resource "aws_appautoscaling_policy" "cpu" {
  name               = "${local.name_prefix}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.autoscaling_cpu_target
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# Scale on memory utilization
resource "aws_appautoscaling_policy" "memory" {
  name               = "${local.name_prefix}-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.autoscaling_memory_target
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}

# Scale on request count per target
resource "aws_appautoscaling_policy" "requests" {
  name               = "${local.name_prefix}-requests-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 1000
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.main.arn_suffix}/${aws_lb_target_group.app.arn_suffix}"
    }
  }
}
