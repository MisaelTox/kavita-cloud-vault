# 1. Definir el proveedor y la región
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# 2. VPC
resource "aws_vpc" "kavita_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "${var.project_name}-vpc" }
}

# 3. Subred
resource "aws_subnet" "kavita_public_subnet" {
  vpc_id                  = aws_vpc.kavita_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"
  tags                 = { Name = "${var.project_name}-public-subnet" }
}

# 4. Internet Gateway
resource "aws_internet_gateway" "kavita_igw" {
  vpc_id = aws_vpc.kavita_vpc.id
  tags   = { Name = "${var.project_name}-igw" }
}

# 5. Routing
resource "aws_route_table" "kavita_rt" {
  vpc_id = aws_vpc.kavita_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.kavita_igw.id
  }
}

resource "aws_route_table_association" "kavita_rta" {
  subnet_id      = aws_subnet.kavita_public_subnet.id
  route_table_id = aws_route_table.kavita_rt.id
}

# 6. Almacenamiento EFS
resource "aws_efs_file_system" "kavita_storage" {
  creation_token = "kavita-storage"
  encrypted      = true
  tags           = { Name = "kavita-efs" }
}

resource "aws_efs_mount_target" "kavita_mount" {
  file_system_id  = aws_efs_file_system.kavita_storage.id
  subnet_id       = aws_subnet.kavita_public_subnet.id
  security_groups = [aws_security_group.efs_sg.id]
}

# 7. Security Groups
resource "aws_security_group" "efs_sg" {
  name   = "efs-kavita-sg"
  vpc_id = aws_vpc.kavita_vpc.id
  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.kavita_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "kavita_sg" {
  name   = "kavita-web-sg"
  vpc_id = aws_vpc.kavita_vpc.id
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
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
}

# 8. CloudWatch Logs (Para ver qué pasa si no arranca)
resource "aws_cloudwatch_log_group" "kavita_logs" {
  name              = "/ecs/kavita"
  retention_in_days = 7
}

# 9. ECS Cluster
resource "aws_ecs_cluster" "kavita_cluster" {
  name = "kavita-cluster"
}

# 10. Task Definition (SIDE-BY-SIDE)
resource "aws_ecs_task_definition" "kavita_task" {
  family                   = "kavita-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  volume {
    name = "kavita-storage"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.kavita_storage.id
      root_directory = "/"
    }
  }

container_definitions = jsonencode([
    {
      name         = "kavita"
      image        = "lscr.io/linuxserver/kavita:latest"
      essential    = true
      portMappings = [{ containerPort = 5000, hostPort = 5000 }]
      environment = [
        { name = "TZ", value = var.timezone },
        { name = "PUID", value = "1000" },
        { name = "PGID", value = "1000" }
      ]
      mountPoints = [
        { sourceVolume = "kavita-storage", containerPath = "/config", readOnly = false },
        { sourceVolume = "kavita-storage", containerPath = "/data", readOnly = false }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.kavita_logs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "kavita"
        }
      }
    },
    {
      name         = "file-manager"
      image        = "filebrowser/filebrowser:latest"
      essential    = true
      portMappings = [{ containerPort = 8080, hostPort = 8080 }]
      command = [
        "--noauth",
        "--address", "0.0.0.0",
        "--port", "8080",
        "--root", "/srv",
        "--database", "/srv/filebrowser.db"
      ]
      mountPoints = [
        { sourceVolume = "kavita-storage", containerPath = "/srv", readOnly = false }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.kavita_logs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "file-manager"
        }
      }
    }
  ]) # <--- Aquí estaba el cierre que faltaba
}

# 11. ECS Service
resource "aws_ecs_service" "kavita_service" {
  name            = "kavita-service"
  cluster         = aws_ecs_cluster.kavita_cluster.id
  task_definition = aws_ecs_task_definition.kavita_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = [aws_subnet.kavita_public_subnet.id]
    security_groups  = [aws_security_group.kavita_sg.id]
    assign_public_ip = true
  }

  depends_on = [aws_efs_mount_target.kavita_mount]
}

# 12. IAM Roles
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "kavita-ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}