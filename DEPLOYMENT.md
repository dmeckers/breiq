# 🚀 Breiq Deployment Guide

## GitHub Actions CI/CD Pipeline

This repository uses GitHub Actions for automated deployment to AWS ECS.

### 🔧 Setup GitHub Secrets

Go to your GitHub repository settings and add these secrets:

1. **AWS_ACCESS_KEY_ID**: Your AWS access key
2. **AWS_SECRET_ACCESS_KEY**: Your AWS secret access key

### 📝 Getting AWS Credentials

From your local AWS profile, get the credentials:

```bash
# Show your current AWS credentials
cat ~/.aws/credentials

# Or show specific profile
aws configure list --profile breiq
```

### 🎯 Pipeline Triggers

The pipeline automatically triggers on:
- Push to `main` or `master` branch
- PR merge to `main` or `master` branch

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