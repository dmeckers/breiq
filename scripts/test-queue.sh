#!/bin/bash

# ====================================
# BREIQ QUEUE TEST SCRIPT
# Test SQS connection and job dispatch
# ====================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

AWS_REGION="us-east-1"
ECS_CLUSTER="breiq-production-cluster"
ECS_SERVICE="breiq-production-backend"

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

# Get running task
get_running_task() {
    aws ecs list-tasks \
        --cluster $ECS_CLUSTER \
        --service $ECS_SERVICE \
        --desired-status RUNNING \
        --region $AWS_REGION \
        --query 'taskArns[0]' \
        --output text
}

main() {
    log "🧪 Testing Breiq Queue System"
    echo "=================================="
    
    # Get running task
    log "Getting running ECS task..."
    TASK_ARN=$(get_running_task)
    
    if [ "$TASK_ARN" = "None" ] || [ -z "$TASK_ARN" ]; then
        log_error "No running tasks found"
        exit 1
    fi
    
    TASK_ID=$(echo $TASK_ARN | cut -d'/' -f3)
    log "Found running task: $TASK_ID"
    
    # Run SQS connection test
    log "🔄 Running SQS connection test..."
    aws ecs execute-command \
        --cluster $ECS_CLUSTER \
        --task "$TASK_ARN" \
        --container breiq-backend \
        --command "php /app/artisan queue:test-sqs" \
        --interactive \
        --region $AWS_REGION
    
    echo ""
    log "🔍 Checking queue worker status..."
    aws ecs execute-command \
        --cluster $ECS_CLUSTER \
        --task "$TASK_ARN" \
        --container breiq-backend \
        --command "ps aux | grep queue:work" \
        --interactive \
        --region $AWS_REGION
    
    echo ""
    log "📊 Checking Laravel logs..."
    aws ecs execute-command \
        --cluster $ECS_CLUSTER \
        --task "$TASK_ARN" \
        --container breiq-backend \
        --command "tail -n 20 /app/storage/logs/laravel.log" \
        --interactive \
        --region $AWS_REGION || echo "No logs found yet"
    
    log_success "Queue test completed!"
    log "💡 Next steps:"
    echo "  1. Check AWS SQS console for new messages"
    echo "  2. Monitor queue worker logs"
    echo "  3. Check Telescope for job status"
}

# Run main function
main "$@"