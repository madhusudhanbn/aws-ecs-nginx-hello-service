# Define provider block for AWS
provider "aws" {
  region = var.aws_region
}

# Create a VPC
resource "aws_vpc" "web_app_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}

# Create a private subnet for the ECS tasks
resource "aws_subnet" "web_app_private_subnet" {
  vpc_id = aws_vpc.web_app_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

# Create an Application Load Balancer (ALB) in a public subnet
resource "aws_lb" "web_app_lb" {
  name = "web-app-lb"
  load_balancer_type = "application"
  subnets = [aws_subnet.web_app_public_subnet.id]
  enable_deletion_protection = false
  enable_http2 = true

  security_groups = [aws_security_group.web_app_lb_sg.id]  # Associate ALB with the security group
}

# Create a security group for the ALB
resource "aws_security_group" "web_app_lb_sg" {
  name = "web-app-lb-sg"

  # Define security group rules for the ALB
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow incoming traffic from internet
  }
}

# Define a target group for the ALB
resource "aws_lb_target_group" "web_app_target_group" {
  name     = "web-app-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.web_app_vpc.id
}

# Create an IAM role for ECS tasks
resource "aws_iam_role" "ecs_task_role" {
  name = "web-app-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Attach the AmazonECSTaskExecutionRolePolicy to the ECS task role
resource "aws_iam_policy_attachment" "ecs_task_execution_role_policy_attachment" {
  name = "ecs-task-execution-policy-attachment"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  roles = [aws_iam_role.ecs_task_role.name]
}

# Create ECS task definition
resource "aws_ecs_task_definition" "web_app_task" {
  family                   = "web-app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_role.arn

  # Define container(s) for the task
  container_definitions = jsonencode([
    {
      name  = "web-app-container"
      image = "nginxdemos/hello"
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}

# Create an ECS cluster
resource "aws_ecs_cluster" "web_app_cluster" {
  name = "web-app-cluster"
}

# Create an ECS service
resource "aws_ecs_service" "web_app_service" {
  name            = "web-app-service"
  cluster         = aws_ecs_cluster.web_app_cluster.id
  task_definition = aws_ecs_task_definition.web_app_task.arn
  launch_type     = "FARGATE"

  network_configuration {
    subnets = [aws_subnet.web_app_private_subnet.id]  # Use the private subnet
  }
}

# Output the DNS name of the ALB
output "web_app_url" {
  value = aws_lb.web_app_lb.dns_name
}
