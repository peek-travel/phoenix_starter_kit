output "alb_dns_name" {
  description = "ALB DNS name — point your domain here (CNAME)"
  value       = aws_lb.main.dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL for pushing Docker images"
  value       = aws_ecr_repository.app.repository_url
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.main.endpoint
}

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint (only set when enable_redis = true)"
  value       = var.enable_redis ? "${aws_elasticache_cluster.main[0].cache_nodes[0].address}:6379" : null
}

output "ecs_cluster_name" {
  description = "ECS cluster name (used by CI/CD)"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name (used by CI/CD)"
  value       = aws_ecs_service.app.name
}

output "ssm_database_url_arn" {
  description = "SSM Parameter ARN for DATABASE_URL (reference this in other TF configs)"
  value       = aws_ssm_parameter.database_url.arn
}

output "acm_certificate_validation_records" {
  description = "CNAME records to add in Cloudflare to validate the ACM certificate. Run during terraform apply (while it blocks) and add to Cloudflare DNS-only (not proxied)."
  value = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate attached to the HTTPS listener"
  value       = aws_acm_certificate_validation.main.certificate_arn
}
