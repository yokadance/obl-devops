# modules/efs/outputs.tf
output "efs_id" {
  description = "EFS file system ID"
  value       = aws_efs_file_system.main.id
}

output "efs_arn" {
  description = "EFS file system ARN"
  value       = aws_efs_file_system.main.arn
}

output "postgres_access_point_id" {
  description = "EFS access point ID for PostgreSQL"
  value       = aws_efs_access_point.postgres.id
}

output "redis_access_point_id" {
  description = "EFS access point ID for Redis"
  value       = aws_efs_access_point.redis.id
}