# --- ElastiCache Redis (optional) ---
#
# Only provisioned when enable_redis = true in your tfvars.
# Set enable_redis = true and set redis_node_type if your app uses Redis.

resource "aws_elasticache_subnet_group" "main" {
  count = var.enable_redis ? 1 : 0

  name       = "${local.name_prefix}-redis-subnet"
  subnet_ids = aws_subnet.private[*].id

  tags = { Name = "${local.name_prefix}-redis-subnet-group" }
}

resource "aws_elasticache_cluster" "main" {
  count = var.enable_redis ? 1 : 0

  cluster_id = "${local.name_prefix}-redis"

  engine               = "redis"
  engine_version       = "7.1"
  node_type            = var.redis_node_type
  num_cache_nodes      = 1
  port                 = 6379
  parameter_group_name = "default.redis7"

  subnet_group_name  = aws_elasticache_subnet_group.main[0].name
  security_group_ids = [aws_security_group.redis[0].id]

  # Maintenance
  maintenance_window = "sun:05:00-sun:06:00"

  tags = { Name = "${local.name_prefix}-redis" }
}
