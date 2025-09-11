# Queue Worker Task Definition
resource "aws_ecs_task_definition" "queue_worker" {
  family                   = "${var.project_name}-${var.environment}-queue-worker"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  
  container_definitions = jsonencode([
    {
      name  = "${var.project_name}-queue-worker"
      image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/breiq-backend:latest"
      
      # Override default command to run queue worker only
      command = [
        "php", "/app/artisan", "queue:work", "sqs", 
        "--queue=breiq-production-queue,breiq-production-ai-moderation", 
        "--sleep=3", 
        "--tries=3", 
        "--timeout=300", 
        "--verbose",
        "--memory=512"
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "queue-worker"
        }
      }
      
      environment = [
        {
          name  = "APP_ENV"
          value = var.environment
        },
        {
          name  = "LOG_CHANNEL" 
          value = "stderr"
        }
      ]

      healthCheck = {
        command = ["CMD-SHELL", "pgrep -f 'queue:work' || exit 1"]
        interval = 30
        timeout = 5
        retries = 3
        startPeriod = 60
      }
      
      essential = true
    }
  ])

  tags = {
    Name = "${var.project_name}-${var.environment}-queue-worker-task"
  }
}

# Queue Worker Service
resource "aws_ecs_service" "queue_worker" {
  name            = "${var.project_name}-${var.environment}-queue-worker"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.queue_worker.arn
  desired_count   = 2  # Run 2 dedicated queue worker instances
  launch_type     = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  # Service discovery for monitoring
  service_registries {
    registry_arn = aws_service_discovery_service.queue_worker.arn
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-queue-worker-service"
  }
}

# Service Discovery for Queue Workers
resource "aws_service_discovery_private_dns_namespace" "queue_workers" {
  name = "${var.project_name}-${var.environment}-queue-workers.local"
  vpc  = aws_vpc.main.id
  
  tags = {
    Name = "${var.project_name}-${var.environment}-queue-workers-namespace"
  }
}

resource "aws_service_discovery_service" "queue_worker" {
  name = "queue-worker"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.queue_workers.id
    
    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  
  tags = {
    Name = "${var.project_name}-${var.environment}-queue-worker-discovery"
  }
}