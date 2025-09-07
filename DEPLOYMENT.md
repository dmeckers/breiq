# 🚀 Breiq Deployment Guide

## GitHub Actions CI/CD Pipeline

This repository uses GitHub Actions for automated deployment to AWS ECS.

### 🔧 Setup GitHub Secrets

Go to your GitHub repository Settings → Secrets and variables → Actions → New repository secret.

Add ALL of these secrets (case-sensitive):

**AWS Deployment:**
1. **AWS_ACCESS_KEY_ID**: Your AWS access key
2. **AWS_SECRET_ACCESS_KEY**: Your AWS secret access key
3. **AWS_ACCOUNT_ID**: Your 12-digit AWS account ID

**Laravel Application:**
4. **APP_KEY**: Laravel app key (generate with: `php artisan key:generate --show`)
5. **APP_URL**: Your ALB DNS (e.g., `http://breiq-production-alb-123456789.us-east-1.elb.amazonaws.com`)

**Database (from Terraform outputs):**
6. **DB_HOST**: RDS PostgreSQL endpoint
7. **DB_PASSWORD**: Database password you set

**Cache (from Terraform outputs):**
8. **REDIS_HOST**: ElastiCache Redis endpoint

**Google OAuth (from your existing app):**
9. **GOOGLE_CLIENT_ID**: Your Google OAuth client ID
10. **GOOGLE_CLIENT_SECRET**: Your Google OAuth client secret

**Firebase (from your existing app):**
11. **FCM_SERVER_KEY**: Firebase Cloud Messaging server key
12. **FCM_SENDER_ID**: Firebase Cloud Messaging sender ID

**Telegram Notifications:**
13. **TELEGRAM_TO**: Your Telegram chat ID (get from @userinfobot)
14. **TELEGRAM_TOKEN**: Your Telegram bot token (get from @BotFather)

**Optional:**
15. **CLOUDFRONT_URL**: CloudFront distribution URL (if using CDN)
16. **SENTRY_LARAVEL_DSN**: Sentry DSN for error tracking (if using Sentry)

### 📝 Getting AWS Credentials

From your local AWS profile, get the credentials:

```bash
# Show your current AWS credentials
cat ~/.aws/credentials

# Or show specific profile
aws configure list --profile breiq
```

### 📱 Setting Up Telegram Notifications

1. **Create a Telegram Bot:**
   - Message @BotFather on Telegram
   - Send `/newbot` and follow instructions
   - Save the bot token (looks like: `123456789:ABCdefGHIjklMNOpqrSTUVwxyZ`)

2. **Get Your Chat ID:**
   - Message @userinfobot on Telegram
   - Send `/start`
   - Save your chat ID (looks like: `123456789`)

3. **Add to GitHub Secrets:**
   - `TELEGRAM_TOKEN`: Your bot token
   - `TELEGRAM_TO`: Your chat ID

### 🎯 Pipeline Triggers

The pipeline automatically triggers on:
- Push to `main` or `master` branch  
- PR merge to `main` or `master` branch

**Telegram Notifications Include:**
- 🚀 Deployment start notification
- ✅ Success with live endpoints and container details
- ❌ Failure with troubleshooting steps and logs

### 🏗️ What the Pipeline Does

1. **Checkout code** from GitHub
2. **Build Docker image** with Laravel backend
3. **Push to AWS ECR** registry  
4. **Deploy to ECS** Fargate cluster
5. **Run database migrations** automatically
6. **Health check** API endpoint

### 🌐 Infrastructure

- **ECS Cluster**: `breiq-production-cluster`
- **ECS Service**: `breiq-production-backend`
- **Load Balancer**: `breiq-production-alb`
- **Database**: PostgreSQL on RDS
- **Cache**: Redis on ElastiCache
- **Storage**: S3 for videos

### 🔍 Monitoring

Check deployment status:
- GitHub Actions tab in your repository
- AWS ECS console for service health
- CloudWatch logs for application logs

### 🚀 API Endpoints

After successful deployment:
- **Health Check**: `http://your-alb-dns.amazonaws.com/api/health`
- **API Base**: `http://your-alb-dns.amazonaws.com/api/`

### 🐛 Troubleshooting

If deployment fails:
1. Check GitHub Actions logs
2. Check ECS service events
3. Check CloudWatch logs: `/ecs/breiq-production`
4. Verify AWS credentials in GitHub secrets

### 🔄 Manual Deployment

To manually trigger deployment:
```bash
# Push to main branch
git add .
git commit -m "Deploy: your changes"
git push origin main
```

### 📱 Next Steps

After API is deployed:
1. Configure Flutter app to use the API endpoint
2. Test mobile app with live API
3. Set up monitoring and alerts