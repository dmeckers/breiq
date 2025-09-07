# Laravel AWS Migration Guide

## 🔄 Current vs AWS Services Migration

### Current Local Setup → AWS Services

| **Service** | **Current (Docker)** | **AWS Replacement** | **Configuration Change** |
|-------------|---------------------|---------------------|-------------------------|
| **Database** | MySQL (docker) | RDS PostgreSQL | DB_CONNECTION=pgsql |
| **Cache/Session** | Redis (docker) | ElastiCache Redis | REDIS_HOST=aws-endpoint |
| **File Storage** | MinIO (docker) | S3 + CloudFront | FILESYSTEM_DISK=s3 |
| **Queue** | Database queue | SQS | QUEUE_CONNECTION=sqs |
| **Video Processing** | Local FFmpeg | Lambda + S3 | Background processing |

## 🛠️ Required Laravel Configuration Changes

### 1. Database Configuration (PostgreSQL)

**Current (MySQL):**
```env
DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
```

**AWS (PostgreSQL):**
```env
DB_CONNECTION=pgsql
DB_HOST=your-rds-endpoint.amazonaws.com
DB_PORT=5432
DB_DATABASE=breiq_production
```

### 2. File Storage Configuration (S3)

**Current (MinIO):**
```env
FILESYSTEM_DISK=s3
AWS_ENDPOINT=http://minio:9000
AWS_USE_PATH_STYLE_ENDPOINT=true
AWS_BUCKET=breiq-videos
```

**AWS (S3):**
```env
FILESYSTEM_DISK=s3
AWS_ENDPOINT=                    # Remove for real S3
AWS_USE_PATH_STYLE_ENDPOINT=false
AWS_BUCKET=breiq-production-videos
AWS_DEFAULT_REGION=us-east-1
```

### 3. Cache & Sessions (ElastiCache)

**Current (Docker Redis):**
```env
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=
```

**AWS (ElastiCache):**
```env
REDIS_HOST=your-elasticache-endpoint.amazonaws.com
REDIS_PORT=6379
REDIS_PASSWORD=                  # Usually empty for ElastiCache
```

### 4. Queue Configuration (SQS)

**Current (Database):**
```env
QUEUE_CONNECTION=database
```

**AWS (SQS):**
```env
QUEUE_CONNECTION=sqs
SQS_PREFIX=https://sqs.us-east-1.amazonaws.com/021891607194
SQS_QUEUE=breiq-production-queue
```

## 📋 Step-by-Step Migration Process

### Step 1: Update Database Configuration

Your current `config/database.php` already supports PostgreSQL. You just need to:

1. **Change default connection:**
```php
// In config/database.php
'default' => env('DB_CONNECTION', 'pgsql'),  // Change from 'sqlite'
```

2. **Update environment:**
```env
DB_CONNECTION=pgsql
DB_HOST=your-rds-endpoint
DB_PORT=5432
DB_DATABASE=breiq_production
DB_USERNAME=breiq_admin
DB_PASSWORD=your-secure-password
```

### Step 2: Update File Storage Configuration

Your `config/filesystems.php` is already configured for S3. You just need to update environment:

```env
# Remove MinIO-specific settings
# AWS_ENDPOINT=http://minio:9000          # Remove this line
# AWS_USE_PATH_STYLE_ENDPOINT=true       # Change to false

# Update for AWS S3
AWS_ACCESS_KEY_ID=your-iam-user-key
AWS_SECRET_ACCESS_KEY=your-iam-user-secret
AWS_DEFAULT_REGION=us-east-1
AWS_BUCKET=breiq-production-videos
AWS_USE_PATH_STYLE_ENDPOINT=false
```

### Step 3: Update Queue Configuration

Your `config/queue.php` already supports SQS. Update environment:

```env
QUEUE_CONNECTION=sqs
AWS_ACCESS_KEY_ID=your-iam-user-key      # Same as S3
AWS_SECRET_ACCESS_KEY=your-iam-user-secret # Same as S3
SQS_PREFIX=https://sqs.us-east-1.amazonaws.com/021891607194
SQS_QUEUE=breiq-production-queue
AWS_DEFAULT_REGION=us-east-1
```

### Step 4: Update Redis Configuration

No code changes needed, just environment:

```env
REDIS_HOST=your-elasticache-endpoint.cache.amazonaws.com
REDIS_PORT=6379
REDIS_PASSWORD=                          # Usually empty
```

## 🔧 Code Changes Required

### 1. Video Processing Service Updates

Your `VideoService` needs minor updates for S3:

```php
// In app/Services/VideoService.php
public function processVideo($file, $moveId)
{
    // Upload to S3 instead of local storage
    $path = Storage::disk('s3')->putFile(
        'videos/' . auth()->id() . '/' . $moveId,
        $file,
        'public'
    );
    
    // Get S3 URL for the video
    $url = Storage::disk('s3')->url($path);
    
    return [
        'path' => $path,
        'url' => $url
    ];
}
```

### 2. Update Video Processing Jobs

Your existing jobs (`ProcessVideoUploadJob`, `AIVideoModerationJob`) need minor updates:

```php
// In app/Jobs/ProcessVideoUploadJob.php
public function handle()
{
    // Download from S3 for processing
    $tempFile = Storage::disk('s3')->get($this->videoPath);
    
    // Process video (FFmpeg operations)
    // ...
    
    // Upload processed video back to S3
    Storage::disk('s3')->put($processedPath, $processedVideo);
}
```

### 3. Environment-Specific Configuration

Create production environment file:

```bash
# Copy the AWS environment template
cp .env.aws.example .env.production

# Edit with your actual AWS values
nano .env.production
```

## ⚙️ Docker Configuration Updates

### 1. Update Dockerfile for Production

Your current deployment script already creates a production Dockerfile. No changes needed!

### 2. Remove Local Services Dependencies

For AWS deployment, you won't need:
- MySQL container
- Redis container  
- MinIO container
- Local AI moderator

The ECS deployment will only run your Laravel app container.

## 🚀 Deployment Process

### 1. After Terraform Deployment

Once Terraform creates your AWS infrastructure, you'll get outputs like:

```bash
# Run this to get your AWS endpoints
terraform output

# Example outputs:
# rds_endpoint = "breiq-prod-db.123456.us-east-1.rds.amazonaws.com"
# redis_endpoint = "breiq-prod-redis.123456.cache.amazonaws.com"
# s3_bucket_name = "breiq-production-videos-abc123"
# sqs_queue_url = "https://sqs.us-east-1.amazonaws.com/021891607194/breiq-production-queue"
```

### 2. Update Laravel Environment

```bash
# Update .env.production with the Terraform outputs
DB_HOST=breiq-prod-db.123456.us-east-1.rds.amazonaws.com
REDIS_HOST=breiq-prod-redis.123456.cache.amazonaws.com
AWS_BUCKET=breiq-production-videos-abc123
SQS_PREFIX=https://sqs.us-east-1.amazonaws.com/021891607194
```

### 3. Deploy Laravel to ECS

```bash
# Run the deployment script
cd scripts/
./deploy-laravel.sh production us-east-1 breiq
```

## 🔍 Testing the Migration

### 1. Test Database Connection

```bash
# SSH into ECS container or run locally with AWS credentials
php artisan migrate:status
```

### 2. Test File Upload

```bash
# Test S3 storage
php artisan tinker
>>> Storage::disk('s3')->put('test.txt', 'Hello AWS!');
>>> Storage::disk('s3')->get('test.txt');
```

### 3. Test Queue Processing

```bash
# Test SQS queue
php artisan queue:work sqs --once
```

## ⚠️ Important Notes

### 1. No Code Architecture Changes

Your Laravel app architecture stays the same:
- Same controllers, models, services
- Same API endpoints
- Same business logic
- Only infrastructure connections change

### 2. Backwards Compatibility

Keep your existing Docker Compose setup for local development:
- Local development: Use Docker (MySQL, Redis, MinIO)
- Production: Use AWS services (RDS, ElastiCache, S3)

### 3. Environment Variables

The key is using different `.env` files:
- `.env` - Local development with Docker
- `.env.production` - AWS production environment

### 4. Video Processing

Your existing FFmpeg code will work, but processing will happen in:
- **Local**: Docker containers
- **AWS**: ECS containers (or optionally Lambda for heavy processing)

## 📚 What Doesn't Need to Change

✅ **Your existing Laravel code structure**
✅ **API endpoints and routes** 
✅ **Database migrations and models**
✅ **Business logic in services**
✅ **Authentication flow**
✅ **Mobile app API calls**

❌ **Only infrastructure connections change!**