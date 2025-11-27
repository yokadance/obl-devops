# modules/efs/main.tf
resource "aws_efs_file_system" "main" {
  creation_token = "${var.environment}-efs"
  encrypted      = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "${var.environment}-efs"
  }
}

resource "aws_security_group" "efs" {
  name_prefix = "${var.environment}-efs-sg"
  description = "Security group for EFS mount targets"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [var.ecs_tasks_security_group_id]
    description     = "NFS from ECS tasks"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-efs-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_efs_mount_target" "main" {
  count           = length(var.private_subnet_ids)
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = var.private_subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}

# Access points for different services
resource "aws_efs_access_point" "postgres" {
  file_system_id = aws_efs_file_system.main.id

  posix_user {
    gid = 999
    uid = 999
  }

  root_directory {
    path = "/postgres"
    creation_info {
      owner_gid   = 999
      owner_uid   = 999
      permissions = "755"
    }
  }

  tags = {
    Name = "${var.environment}-postgres-ap"
  }
}

resource "aws_efs_access_point" "redis" {
  file_system_id = aws_efs_file_system.main.id

  posix_user {
    gid = 999
    uid = 999
  }

  root_directory {
    path = "/redis"
    creation_info {
      owner_gid   = 999
      owner_uid   = 999
      permissions = "755"
    }
  }

  tags = {
    Name = "${var.environment}-redis-ap"
  }
}