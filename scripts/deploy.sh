#!/bin/bash

# ====================================
# BREIQ INFRASTRUCTURE DEPLOYMENT SCRIPT
# Instagram-level AWS infrastructure deployment
# ====================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="staging"
AWS_REGION="us-east-1"
PROJECT_NAME="breiq"
SKIP_PLAN=false
AUTO_APPROVE=false
DESTROY=false

# Functions
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Deploy Breiq infrastructure to AWS using Terraform"
    echo ""
    echo "Options:"
    echo "  -e, --environment ENVIRONMENT    Target environment (staging|production) [default: staging]"
    echo "  -r, --region REGION             AWS region [default: us-east-1]"
    echo "  -s, --skip-plan                 Skip terraform plan step"
    echo "  -y, --auto-approve             Auto approve terraform apply"
    echo "  -d, --destroy                  Destroy infrastructure instead of creating"
    echo "  -h, --help                     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --environment production --region us-east-1"
    echo "  $0 --environment staging --auto-approve"
    echo "  $0 --environment staging --destroy"
    echo ""
}

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
}

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    # Check if required environment variables are set
    if [[ -z "${TF_STATE_BUCKET:-}" ]]; then
        log_error "TF_STATE_BUCKET environment variable not set"
        exit 1
    fi
    
    if [[ -z "${TF_STATE_LOCK_TABLE:-}" ]]; then
        log_error "TF_STATE_LOCK_TABLE environment variable not set"
        exit 1
    fi
    
    if [[ -z "${DOMAIN_NAME:-}" ]]; then
        log_error "DOMAIN_NAME environment variable not set"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

validate_environment() {
    if [[ ! "$ENVIRONMENT" =~ ^(staging|production)$ ]]; then
        log_error "Invalid environment: $ENVIRONMENT. Must be 'staging' or 'production'"
        exit 1
    fi
}

create_tfvars() {
    log "Creating terraform.tfvars for $ENVIRONMENT environment..."
    
    local cors_origins
    if [[ "$ENVIRONMENT" == "production" ]]; then
        cors_origins="[
    \"https://${DOMAIN_NAME}\",
    \"https://www.${DOMAIN_NAME}\",
    \"https://app.${DOMAIN_NAME}\",
    \"https://admin.${DOMAIN_NAME}\"
  ]"
    else
        cors_origins="[
    \"https://staging.${DOMAIN_NAME}\",
    \"https://app-staging.${DOMAIN_NAME}\"
  ]"
    fi
    
    cat > terraform.tfvars << EOF
# Basic Configuration
aws_region   = "$AWS_REGION"
environment  = "$ENVIRONMENT"
project_name = "$PROJECT_NAME"
domain_name  = "$DOMAIN_NAME"

# Performance Settings
enable_multi_region = $([ "$ENVIRONMENT" = "production" ] && echo "true" || echo "false")

# CORS Origins for Video Access
video_bucket_cors_origins = $cors_origins

# Database Configuration
rds_instance_class = "$([ "$ENVIRONMENT" = "production" ] && echo "db.r6g.xlarge" || echo "db.r6g.large")"
rds_backup_retention = $([ "$ENVIRONMENT" = "production" ] && echo "30" || echo "7")
enable_rds_multi_az = $([ "$ENVIRONMENT" = "production" ] && echo "true" || echo "false")

# Cache Configuration
redis_node_type = "$([ "$ENVIRONMENT" = "production" ] && echo "cache.r6g.xlarge" || echo "cache.r6g.large")"
redis_num_nodes = $([ "$ENVIRONMENT" = "production" ] && echo "3" || echo "2")

# Monitoring and Alerts
enable_enhanced_monitoring = $([ "$ENVIRONMENT" = "production" ] && echo "true" || echo "false")
alert_email = "${ALERT_EMAIL:-admin@${DOMAIN_NAME}}"

# Cost Optimization
enable_spot_instances = $([ "$ENVIRONMENT" = "staging" ] && echo "true" || echo "false")
enable_s3_lifecycle_policies = true
EOF

    log_success "terraform.tfvars created for $ENVIRONMENT"
}

terraform_init() {
    log "Initializing Terraform..."
    
    terraform init \
        -backend-config="bucket=${TF_STATE_BUCKET}" \
        -backend-config="key=${PROJECT_NAME}-${ENVIRONMENT}/terraform.tfstate" \
        -backend-config="region=${AWS_REGION}" \
        -backend-config="dynamodb_table=${TF_STATE_LOCK_TABLE}" \
        -upgrade
    
    log_success "Terraform initialized"
}

terraform_plan() {
    if [[ "$SKIP_PLAN" = true ]]; then
        log_warning "Skipping Terraform plan as requested"
        return
    fi
    
    log "Planning Terraform changes..."
    
    if [[ "$DESTROY" = true ]]; then
        terraform plan -destroy -out=tfplan
    else
        terraform plan -out=tfplan
    fi
    
    # Show plan summary
    echo ""
    log "📋 Terraform Plan Summary:"
    if [[ "$DESTROY" = true ]]; then
        terraform show -json tfplan | jq -r '.planned_values.root_module.resources[]?.address // empty' | wc -l | xargs echo "Resources to destroy:"
    else
        terraform show -json tfplan | jq -r '
            (.resource_changes // []) | 
            group_by(.change.actions[0]) | 
            map({action: .[0].change.actions[0], count: length}) | 
            .[] | 
            "\(.action): \(.count)"
        ' 2>/dev/null || echo "Plan created successfully"
    fi
    echo ""
    
    log_success "Terraform plan completed"
}

terraform_apply() {
    log "Applying Terraform changes..."
    
    if [[ "$AUTO_APPROVE" = true ]]; then
        if [[ "$DESTROY" = true ]]; then
            terraform destroy -auto-approve
        else
            terraform apply -auto-approve tfplan
        fi
    else
        echo ""
        log_warning "⚠️  You are about to $([ "$DESTROY" = true ] && echo "DESTROY" || echo "deploy") infrastructure for environment: $ENVIRONMENT"
        log_warning "⚠️  This will affect Instagram-level infrastructure components!"
        echo ""
        
        read -p "$(echo -e "${YELLOW}Do you want to continue? (yes/no): ${NC}")" -r
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            log "Deployment cancelled by user"
            exit 0
        fi
        
        if [[ "$DESTROY" = true ]]; then
            terraform destroy
        else
            terraform apply tfplan
        fi
    fi
    
    log_success "Terraform apply completed"
}

show_outputs() {
    if [[ "$DESTROY" = true ]]; then
        return
    fi
    
    log "📊 Deployment Outputs:"
    echo ""
    
    # Get important outputs
    if terraform output load_balancer_dns &> /dev/null; then
        echo "🌐 Load Balancer DNS: $(terraform output -raw load_balancer_dns)"
    fi
    
    if terraform output cloudfront_domain &> /dev/null; then
        echo "🚀 CDN Domain: $(terraform output -raw cloudfront_domain)"
    fi
    
    if terraform output api_gateway_endpoint &> /dev/null; then
        echo "🔗 API Gateway: $(terraform output -raw api_gateway_endpoint)"
    fi
    
    if terraform output ecr_repository_url &> /dev/null; then
        echo "📦 ECR Repository: $(terraform output -raw ecr_repository_url)"
    fi
    
    echo ""
    log_success "Instagram-level infrastructure deployed successfully! 🎬✨"
}

health_check() {
    if [[ "$DESTROY" = true ]]; then
        return
    fi
    
    log "Performing health check..."
    
    # Get ALB DNS name
    if ! ALB_DNS=$(terraform output -raw load_balancer_dns 2>/dev/null); then
        log_warning "Could not get load balancer DNS for health check"
        return
    fi
    
    log "Testing health endpoint: http://$ALB_DNS/api/health"
    
    # Wait for infrastructure to be ready
    sleep 60
    
    # Perform health check
    for i in {1..5}; do
        if curl -f -s "http://$ALB_DNS/api/health" > /dev/null 2>&1; then
            log_success "Health check passed! Infrastructure is ready."
            return
        else
            log_warning "Attempt $i/5 failed, retrying in 30s..."
            sleep 30
        fi
    done
    
    log_warning "Health check failed after 5 attempts. Infrastructure may still be initializing."
}

cleanup() {
    log "Cleaning up temporary files..."
    rm -f tfplan terraform.tfvars.backup
}

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -r|--region)
                AWS_REGION="$2"
                shift 2
                ;;
            -s|--skip-plan)
                SKIP_PLAN=true
                shift
                ;;
            -y|--auto-approve)
                AUTO_APPROVE=true
                shift
                ;;
            -d|--destroy)
                DESTROY=true
                shift
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done
    
    # Change to terraform directory
    cd "$(dirname "$0")/../terraform"
    
    # Setup trap for cleanup
    trap cleanup EXIT
    
    echo "🚀 Breiq Infrastructure Deployment"
    echo "=================================="
    echo "Environment: $ENVIRONMENT"
    echo "AWS Region: $AWS_REGION"
    echo "Action: $([ "$DESTROY" = true ] && echo "DESTROY" || echo "DEPLOY")"
    echo ""
    
    # Run deployment steps
    validate_environment
    check_prerequisites
    create_tfvars
    terraform_init
    terraform_plan
    terraform_apply
    
    if [[ "$DESTROY" = false ]]; then
        show_outputs
        health_check
    else
        log_success "Infrastructure destroyed successfully"
    fi
}

# Run main function
main "$@"