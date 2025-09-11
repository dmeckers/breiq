#!/bin/bash

# ====================================
# BREIQ CLEAN SLATE SCRIPT
# Clear all data for fresh testing
# ====================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

AWS_REGION="us-east-1"
PROJECT_NAME="breiq"
ENVIRONMENT="production"

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

# Get S3 buckets
get_buckets() {
    echo "breiq-production-videos-bh3xujb8"
    echo "breiq-production-processed-bh3xujb8" 
    echo "breiq-production-thumbnails-bh3xujb8"
}

# Clear S3 buckets
clear_s3_buckets() {
    log "🗑️ Clearing all S3 buckets..."
    
    for bucket in $(get_buckets); do
        log "Clearing bucket: $bucket"
        
        # Check if bucket exists
        if aws s3api head-bucket --bucket "$bucket" --region $AWS_REGION 2>/dev/null; then
            # Delete all objects (including versions)
            aws s3 rm "s3://$bucket" --recursive --region $AWS_REGION
            log_success "Cleared $bucket"
        else
            log_warning "Bucket $bucket not found or not accessible"
        fi
    done
}

# Purge SQS queues
purge_sqs_queues() {
    log "🗑️ Purging all SQS queues..."
    
    local queues=(
        "https://sqs.us-east-1.amazonaws.com/021891607194/breiq-production-queue"
        "https://sqs.us-east-1.amazonaws.com/021891607194/breiq-production-ai-moderation"
        "https://sqs.us-east-1.amazonaws.com/021891607194/breiq-production-dlq"
    )
    
    for queue_url in "${queues[@]}"; do
        queue_name=$(basename "$queue_url")
        log "Purging queue: $queue_name"
        
        aws sqs purge-queue --queue-url "$queue_url" --region $AWS_REGION 2>/dev/null || log_warning "Could not purge $queue_name"
    done
    
    log_success "SQS queues purged"
}

# Clear database data
clear_database_data() {
    log "🗑️ Clearing database test data..."
    
    # Get ECS task ARN
    TASK_ARN=$(aws ecs list-tasks \
        --cluster breiq-production-cluster \
        --service breiq-production-backend \
        --desired-status RUNNING \
        --region $AWS_REGION \
        --query 'taskArns[0]' \
        --output text)
    
    if [ "$TASK_ARN" = "None" ] || [ -z "$TASK_ARN" ]; then
        log_error "No running backend tasks found"
        return 1
    fi
    
    log "Found running task, clearing database..."
    
    # Clear videos and related data
    aws ecs execute-command \
        --cluster breiq-production-cluster \
        --task "$TASK_ARN" \
        --container breiq-backend \
        --command "php /app/artisan tinker --execute=\"\\App\\Models\\Video::truncate(); echo 'Videos cleared';\"" \
        --interactive \
        --region $AWS_REGION || log_warning "Could not clear videos"
    
    # Clear failed jobs
    aws ecs execute-command \
        --cluster breiq-production-cluster \
        --task "$TASK_ARN" \
        --container breiq-backend \
        --command "php /app/artisan queue:clear sqs" \
        --interactive \
        --region $AWS_REGION || log_warning "Could not clear queue"
        
    # Clear telescope entries
    aws ecs execute-command \
        --cluster breiq-production-cluster \
        --task "$TASK_ARN" \
        --container breiq-backend \
        --command "php /app/artisan telescope:clear" \
        --interactive \
        --region $AWS_REGION || log_warning "Could not clear telescope"
        
    log_success "Database cleared"
}

# Main cleanup function
main() {
    echo "🧹 Breiq Clean Slate Cleanup"
    echo "============================"
    
    log_warning "⚠️  This will DELETE ALL test data!"
    log_warning "⚠️  S3 files, queues, database records, telescope logs"
    echo ""
    
    read -p "$(echo -e "${YELLOW}Are you sure you want to continue? (yes/no): ${NC}")" -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log "Cleanup cancelled"
        exit 0
    fi
    
    log "Starting complete cleanup..."
    
    # Run cleanup steps
    clear_s3_buckets
    purge_sqs_queues
    clear_database_data
    
    echo ""
    log_success "🎉 Complete cleanup finished!"
    log "💡 Ready for fresh testing:"
    echo "  1. Upload a new video via API/app"
    echo "  2. Watch CloudWatch logs for processing"
    echo "  3. Check Telescope for job progress"
    echo "  4. Verify video appears in S3 buckets"
}

# Run main function
main "$@"