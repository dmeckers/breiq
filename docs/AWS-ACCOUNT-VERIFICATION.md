# AWS Account Verification & Setup Guide

## 🔍 How to Check Which AWS Account You're Using

### 1. Check Current AWS Account
```bash
# Check your default profile (corporate account)
aws sts get-caller-identity

# Check your breiq profile (personal account)
aws sts get-caller-identity --profile breiq
```

**Example Output:**
```json
{
    "UserId": "AIDACKCEVSQ6C2EXAMPLE",
    "Account": "123456789012",        # ← This is your AWS Account ID
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

### 2. Verify You Have TWO Different Account IDs
```bash
# Corporate account
aws sts get-caller-identity
# Should show: Account ID like "111111111111"

# Personal account  
aws sts get-caller-identity --profile breiq
# Should show: Account ID like "222222222222" (different number)
```

If both commands show the **same Account ID**, you're using the same account for both!

### 3. Check All Your Configured Profiles
```bash
# List all AWS profiles
cat ~/.aws/credentials

# Should show:
# [default]              # ← Corporate account
# aws_access_key_id = AKIA...
# aws_secret_access_key = ...
#
# [breiq]                # ← Personal account  
# aws_access_key_id = AKIA...
# aws_secret_access_key = ...
```

## 🏗️ What You Need to Change in AWS Console

### ✅ Things Terraform Will Handle Automatically
- **VPC and Networking** - Creates new VPC, subnets, security groups
- **Load Balancer** - Creates Application Load Balancer with DNS
- **Database** - Creates RDS PostgreSQL instance
- **Storage** - Creates S3 buckets for videos
- **Container Service** - Creates ECS cluster and services
- **Monitoring** - Creates CloudWatch alarms and dashboards

### ❌ Things You DON'T Need to Change Manually
- **No manual security groups**
- **No manual IAM roles** (Terraform creates them)
- **No manual VPC setup**
- **No manual database creation**
- **No manual load balancer setup**

### 🔧 Only Manual Steps Needed

#### 1. Get AWS Access Keys (One-time setup)
```bash
# In AWS Console for your PERSONAL account:
# 1. Go to IAM → Users → Your User → Security Credentials
# 2. Create Access Key → CLI → Download CSV
# 3. Configure: aws configure --profile breiq
```

#### 2. Verify IAM Permissions
Your user needs **AdministratorAccess** policy or these specific permissions:
- EC2 (full access)
- RDS (full access)  
- S3 (full access)
- ECS (full access)
- IAM (create/modify roles)
- CloudWatch (full access)

## 🌐 Domain Settings (breiq.online on Hetzner)

### Option 1: Keep Domain on Hetzner (Recommended for now)
```bash
# You DON'T need to transfer your domain to AWS
# Just point it to AWS after deployment:

# 1. Deploy Terraform first
terraform apply

# 2. Get the Load Balancer DNS
terraform output application_endpoints

# 3. In Hetzner DNS settings, create:
# Type: CNAME
# Name: api
# Value: your-alb-dns.us-east-1.elb.amazonaws.com
# 
# This gives you: api.breiq.online → AWS API
```

### Option 2: Use AWS Route 53 (Advanced)
```bash
# If you want AWS to manage DNS:
# 1. Transfer domain to Route 53 (costs $12/year)
# 2. Change nameservers at Hetzner to AWS nameservers
# 3. Terraform will manage DNS records automatically
```

### Option 3: Just Use AWS Load Balancer DNS (Simplest)
```bash
# Skip domain setup entirely for now:
# 1. Deploy with Terraform
# 2. Use the ALB DNS directly in Flutter app:
# API URL: breiq-production-alb-1234567890.us-east-1.elb.amazonaws.com
```

## 🚀 Complete Verification Checklist

### ✅ Pre-Deployment Checks

1. **Verify Personal AWS Account:**
```bash
aws sts get-caller-identity --profile breiq
# Account ID should be YOUR personal account (not corporate)
```

2. **Check IAM Permissions:**
```bash
aws iam get-user --profile breiq
# Should return your user info without errors
```

3. **Test Basic AWS Access:**
```bash
aws s3 ls --profile breiq
# Should list buckets or show empty (no error)
```

4. **Verify Terraform Config:**
```bash
cd terraform/
terraform validate
# Should show "Success! The configuration is valid."
```

## 🆘 Troubleshooting Common Issues

### Problem: Same Account ID for Both Profiles
**Solution:** You need a separate personal AWS account
```bash
# 1. Go to aws.amazon.com
# 2. Click "Create an AWS Account" 
# 3. Use different email than your corporate account
# 4. Complete signup with your personal credit card
# 5. Get access keys from the NEW account
```

### Problem: "Access Denied" Errors
**Solution:** Check IAM permissions
```bash
# In AWS Console → IAM → Users → Your User → Permissions
# Attach policy: AdministratorAccess
```

### Problem: Corporate IT Restrictions
**Solution:** Use completely separate personal account
```bash
# Personal AWS account requirements:
# - Different email address
# - Your personal credit card  
# - No corporate IT involvement
# - Full administrator access
```

## 📋 What You Actually Need to Do

### Immediate Steps:
1. **Verify you have separate personal AWS account**
2. **Configure AWS CLI with personal account credentials**
3. **Edit terraform.tfvars with your email**
4. **Deploy infrastructure with Terraform**

### Domain Steps (Later):
1. **Deploy first, get ALB DNS**  
2. **Test API with ALB DNS in Flutter app**
3. **Optionally set up custom domain after everything works**

### No Need To:
- ❌ Change nameservers now
- ❌ Set up Route 53 initially  
- ❌ Configure anything manually in AWS Console
- ❌ Create databases/security groups manually
- ❌ Set up load balancers manually

**Bottom line:** Just configure AWS CLI with your personal account, run Terraform, and you'll get a working API endpoint!