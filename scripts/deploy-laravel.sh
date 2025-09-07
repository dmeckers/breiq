#!/bin/bash

# Breiq Laravel Deployment Script
set -e

echo "🚀 Deploying Breiq Laravel API to AWS ECS..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
ENVIRONMENT=${1:-staging}
AWS_REGION=${2:-us-east-1}
AWS_PROFILE=${3:-breiq}  # Default to 'breiq' profile
PROJECT_NAME="breiq"

# Set AWS profile
export AWS_PROFILE=$AWS_PROFILE

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(staging|production)$ ]]; then
    print_error "Environment must be 'staging' or 'production'"
    exit 1
fi

print_status "Deploying to $ENVIRONMENT environment..."

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPOSITORY_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Create ECR repository if it doesn't exist
print_status "Creating ECR repository..."
aws ecr describe-repositories --repository-names ${PROJECT_NAME}-backend --region ${AWS_REGION} 2>/dev/null || \
aws ecr create-repository --repository-name ${PROJECT_NAME}-backend --region ${AWS_REGION}

# Login to ECR (AWS CLI v1 compatible)
print_status "Logging in to ECR..."
# Check if AWS CLI v2 is available, otherwise use v1 syntax
if aws ecr get-login-password --help >/dev/null 2>&1; then
    # AWS CLI v2
    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPOSITORY_URI}
else
    # AWS CLI v1
    aws ecr get-login --no-include-email --region ${AWS_REGION} | sh
fi

# Build Docker image
print_status "Building Docker image..."
cd ../breiq-backend

# Create production Dockerfile
cat > Dockerfile << 'EOF'
FROM php:8.2-fpm-alpine

# Install system dependencies
RUN apk add --no-cache \
    git \
    curl \
    libpng-dev \
    oniguruma-dev \
    libxml2-dev \
    zip \
    unzip \
    postgresql-dev \
    redis \
    supervisor \
    nginx

# Install PHP extensions
RUN docker-php-ext-install pdo pdo_pgsql mbstring exif pcntl bcmath gd

# Get latest Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www

# Copy existing application directory contents
COPY . /var/www

# Copy existing application directory permissions
COPY --chown=www-data:www-data . /var/www

# Install dependencies (skip scripts to avoid Redis dependency)
RUN composer install --no-dev --optimize-autoloader --no-scripts

# Generate optimized class loader (skip scripts to avoid issues)
RUN composer dump-autoload --optimize --no-scripts

# Copy environment file
COPY .env.production /var/www/.env

# Copy startup script that handles database migrations and optimization
COPY docker/startup.sh /var/www/startup.sh
RUN chmod +x /var/www/startup.sh

# Configure Nginx
COPY docker/nginx.conf /etc/nginx/nginx.conf

# Configure Supervisor
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Configure PHP-FPM
RUN echo "listen = 127.0.0.1:9000" >> /usr/local/etc/php-fpm.d/www.conf

# Create nginx run directory
RUN mkdir -p /var/run/nginx

# Expose port 80
EXPOSE 80

# Start with our startup script that handles migrations and optimization
CMD ["/var/www/startup.sh"]
EOF

# Create Nginx configuration
mkdir -p docker
cat > docker/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    sendfile on;
    keepalive_timeout 65;
    
    server {
        listen 80;
        index index.php index.html;
        root /var/www/public;

        location / {
            try_files $uri $uri/ /index.php?$query_string;
        }

        location ~ \.php$ {
            fastcgi_pass 127.0.0.1:9000;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        }

        location ~ /\.ht {
            deny all;
        }
    }
}
EOF

# Create Supervisor configuration
cat > docker/supervisord.conf << 'EOF'
[supervisord]
nodaemon=true

[program:nginx]
command=nginx -g "daemon off;"
autostart=true
autorestart=true
stderr_logfile=/var/log/nginx/error.log
stdout_logfile=/var/log/nginx/access.log

[program:php-fpm]
command=php-fpm
autostart=true
autorestart=true
EOF

# Build and tag image
IMAGE_TAG=$(date +%Y%m%d%H%M%S)
docker build -t ${PROJECT_NAME}-backend:${IMAGE_TAG} .
docker tag ${PROJECT_NAME}-backend:${IMAGE_TAG} ${ECR_REPOSITORY_URI}/${PROJECT_NAME}-backend:${IMAGE_TAG}
docker tag ${PROJECT_NAME}-backend:${IMAGE_TAG} ${ECR_REPOSITORY_URI}/${PROJECT_NAME}-backend:latest

# Push to ECR
print_status "Pushing image to ECR..."
docker push ${ECR_REPOSITORY_URI}/${PROJECT_NAME}-backend:${IMAGE_TAG}
docker push ${ECR_REPOSITORY_URI}/${PROJECT_NAME}-backend:latest

# Update ECS service (assuming it exists from Terraform)
print_status "Updating ECS service..."
CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}-cluster"
SERVICE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-backend"

# Check if service exists
if aws ecs describe-services --cluster ${CLUSTER_NAME} --services ${SERVICE_NAME} --region ${AWS_REGION} >/dev/null 2>&1; then
    aws ecs update-service \
        --cluster ${CLUSTER_NAME} \
        --service ${SERVICE_NAME} \
        --force-new-deployment \
        --region ${AWS_REGION}
    
    print_status "Waiting for service to stabilize..."
    aws ecs wait services-stable \
        --cluster ${CLUSTER_NAME} \
        --services ${SERVICE_NAME} \
        --region ${AWS_REGION}
else
    print_warning "ECS service not found. You may need to create it first with Terraform."
fi

print_success "Laravel API deployment completed!"
print_status "Your API should be available at the ALB endpoint from Terraform outputs."