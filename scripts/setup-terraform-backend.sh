#!/bin/bash

# ====================================
# TERRAFORM BACKEND SETUP SCRIPT
# Creates S3 bucket and DynamoDB table for Terraform state management
# ====================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-breiq}"
BUCKET_NAME="${TF_STATE_BUCKET:-${PROJECT_NAME}-terraform-state}"
DYNAMODB_TABLE="${TF_STATE_LOCK_TABLE:-${PROJECT_NAME}-terraform-locks}"
FORCE_CREATE=false

# Functions
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Setup Terraform backend infrastructure (S3 + DynamoDB)"
    echo ""
    echo "Options:"
    echo "  -r, --region REGION             AWS region [default: us-east-1]"
    echo "  -p, --project PROJECT           Project name [default: breiq]"
    echo "  -b, --bucket BUCKET             S3 bucket name [default: PROJECT-terraform-state]"
    echo "  -t, --table TABLE               DynamoDB table name [default: PROJECT-terraform-locks]"
    echo "  -f, --force                     Force creation even if resources exist"
    echo "  -h, --help                      Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_REGION                      AWS region"
    echo "  PROJECT_NAME                    Project name"
    echo "  TF_STATE_BUCKET                 S3 bucket name for Terraform state"
    echo "  TF_STATE_LOCK_TABLE            DynamoDB table name for state locking"
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
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    # Check permissions
    local account_id
    account_id=$(aws sts get-caller-identity --query Account --output text)
    log "Using AWS Account: $account_id"
    log "Using AWS Region: $AWS_REGION"
    
    log_success "Prerequisites check passed"
}

create_s3_bucket() {
    log "Creating S3 bucket for Terraform state: $BUCKET_NAME"
    
    # Check if bucket already exists
    if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
        if [[ "$FORCE_CREATE" = false ]]; then
            log_warning "S3 bucket '$BUCKET_NAME' already exists. Use --force to recreate."
            return
        else
            log_warning "S3 bucket '$BUCKET_NAME' exists. Continuing with force flag..."
        fi
    else
        # Create bucket
        if [[ "$AWS_REGION" = "us-east-1" ]]; then
            aws s3api create-bucket \
                --bucket "$BUCKET_NAME" \
                --region "$AWS_REGION"
        else
            aws s3api create-bucket \
                --bucket "$BUCKET_NAME" \
                --region "$AWS_REGION" \
                --create-bucket-configuration LocationConstraint="$AWS_REGION"
        fi
        
        log_success "S3 bucket created: $BUCKET_NAME"
    fi
    
    # Enable versioning
    log "Enabling versioning on S3 bucket..."
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled
    
    # Enable server-side encryption
    log "Enabling server-side encryption on S3 bucket..."
    aws s3api put-bucket-encryption \
        --bucket "$BUCKET_NAME" \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    },
                    "BucketKeyEnabled": true
                }
            ]
        }'
    
    # Block public access
    log "Blocking public access on S3 bucket..."
    aws s3api put-public-access-block \
        --bucket "$BUCKET_NAME" \
        --public-access-block-configuration '{
            "BlockPublicAcls": true,
            "IgnorePublicAcls": true,
            "BlockPublicPolicy": true,
            "RestrictPublicBuckets": true
        }'
    
    # Add lifecycle policy to manage old versions
    log "Adding lifecycle policy to S3 bucket..."
    aws s3api put-bucket-lifecycle-configuration \
        --bucket "$BUCKET_NAME" \
        --lifecycle-configuration '{
            "Rules": [
                {
                    "ID": "terraform-state-lifecycle",
                    "Status": "Enabled",
                    "Filter": {"Prefix": ""},
                    "NoncurrentVersionExpiration": {"NoncurrentDays": 90},
                    "AbortIncompleteMultipartUpload": {"DaysAfterInitiation": 7}
                }
            ]
        }'
    
    log_success "S3 bucket configuration completed"
}

create_dynamodb_table() {
    log "Creating DynamoDB table for Terraform state locking: $DYNAMODB_TABLE"
    
    # Check if table already exists
    if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" &>/dev/null; then
        if [[ "$FORCE_CREATE" = false ]]; then
            log_warning "DynamoDB table '$DYNAMODB_TABLE' already exists. Use --force to recreate."
            return
        else
            log_warning "DynamoDB table '$DYNAMODB_TABLE' exists. Continuing with force flag..."
        fi
    else
        # Create DynamoDB table
        aws dynamodb create-table \
            --table-name "$DYNAMODB_TABLE" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
            --region "$AWS_REGION"
        
        # Wait for table to be created
        log "Waiting for DynamoDB table to be active..."
        aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE"
        
        log_success "DynamoDB table created: $DYNAMODB_TABLE"
    fi
    
    # Enable point-in-time recovery
    log "Enabling point-in-time recovery for DynamoDB table..."
    aws dynamodb update-continuous-backups \
        --table-name "$DYNAMODB_TABLE" \
        --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true
    
    log_success "DynamoDB table configuration completed"
}

create_backend_config() {
    log "Creating Terraform backend configuration..."
    
    local backend_config_dir="../terraform"
    mkdir -p "$backend_config_dir"
    
    cat > "$backend_config_dir/backend.tf" << EOF
# ====================================
# TERRAFORM BACKEND CONFIGURATION
# Auto-generated by setup-terraform-backend.sh
# ====================================

terraform {
  backend "s3" {
    bucket         = "$BUCKET_NAME"
    key            = "global/terraform.tfstate"
    region         = "$AWS_REGION"
    dynamodb_table = "$DYNAMODB_TABLE"
    encrypt        = true
  }
}
EOF

    log_success "Backend configuration created: $backend_config_dir/backend.tf"
}

show_summary() {
    echo ""
    echo "🎉 Terraform Backend Setup Complete!"
    echo "===================================="
    echo ""
    echo "📋 Resources Created:"
    echo "  • S3 Bucket: $BUCKET_NAME"
    echo "  • DynamoDB Table: $DYNAMODB_TABLE"
    echo "  • Region: $AWS_REGION"
    echo ""
    echo "🔧 Environment Variables:"
    echo "  export TF_STATE_BUCKET=\"$BUCKET_NAME\""
    echo "  export TF_STATE_LOCK_TABLE=\"$DYNAMODB_TABLE\""
    echo ""
    echo "📝 Next Steps:"
    echo "  1. Set the environment variables above in your shell"
    echo "  2. Run './deploy.sh --environment staging' to deploy infrastructure"
    echo "  3. Configure GitHub Actions secrets for CI/CD:"
    echo "     - TF_STATE_BUCKET"
    echo "     - TF_STATE_LOCK_TABLE"
    echo "     - AWS_ACCESS_KEY_ID"
    echo "     - AWS_SECRET_ACCESS_KEY"
    echo "     - DOMAIN_NAME"
    echo "     - ALERT_EMAIL"
    echo ""
    
    log_success "Ready to deploy Instagram-level infrastructure! 🚀"
}

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--region)
                AWS_REGION="$2"
                shift 2
                ;;
            -p|--project)
                PROJECT_NAME="$2"
                BUCKET_NAME="${PROJECT_NAME}-terraform-state"
                DYNAMODB_TABLE="${PROJECT_NAME}-terraform-locks"
                shift 2
                ;;
            -b|--bucket)
                BUCKET_NAME="$2"
                shift 2
                ;;
            -t|--table)
                DYNAMODB_TABLE="$2"
                shift 2
                ;;
            -f|--force)
                FORCE_CREATE=true
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
    
    # Change to scripts directory
    cd "$(dirname "$0")"
    
    echo "🔧 Terraform Backend Setup"
    echo "=========================="
    echo "Project: $PROJECT_NAME"
    echo "AWS Region: $AWS_REGION"
    echo "S3 Bucket: $BUCKET_NAME"
    echo "DynamoDB Table: $DYNAMODB_TABLE"
    echo ""
    
    # Run setup steps
    check_prerequisites
    create_s3_bucket
    create_dynamodb_table
    create_backend_config
    show_summary
}

# Run main function
main "$@"