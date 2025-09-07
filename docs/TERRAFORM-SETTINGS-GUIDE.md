# Terraform Settings Variables Guide

## 🔑 Where to Get Each Variable

### 1. AWS Credentials & Configuration

#### AWS Access Keys (Required for CLI setup)
```bash
# Location: AWS Console > IAM > Users > Your User > Security Credentials
# You need:
AWS_ACCESS_KEY_ID=AKIA...           # 20 characters starting with AKIA
AWS_SECRET_ACCESS_KEY=...           # 40 character secret key
```

**How to get them:**
1. Go to [AWS Console](https://console.aws.amazon.com/)
2. Sign in to your **personal AWS account** (not corporate)
3. Navigate: **IAM** → **Users** → **Your Username** → **Security credentials** tab
4. Click **"Create access key"** → **"Command Line Interface (CLI)"**
5. Download the credentials or copy them immediately

#### AWS Region
```bash
aws_region = "us-east-1"    # Choose closest to your users
```

**Popular regions:**
- `us-east-1` (Virginia) - Cheapest, most services
- `us-west-2` (Oregon) - West Coast US
- `eu-west-1` (Ireland) - Europe
- `ap-southeast-1` (Singapore) - Asia

### 2. Domain Configuration (Optional)

#### Domain Name
```bash
domain_name = "breiq.online"        # Your domain or use default
```

**Options:**
- **Own domain**: If you have `breiq.online` or similar
- **Use default**: Keep `breiq.online` for now, change later
- **No domain**: Use ALB DNS directly (we'll show you how)

### 3. Email for Alerts
```bash
alert_email = "your-email@gmail.com"    # Your email for AWS alerts
```

**What you'll receive:**
- Database CPU high alerts
- API error rate alerts
- Infrastructure failure notifications

### 4. Project Customization (Optional)

#### Project Tags
```bash
additional_tags = {
  Owner       = "YourName"          # Your name
  CostCenter  = "Personal"          # Personal/Company
  Project     = "BreiqApp"          # Project identifier
}
```

## 📝 Complete terraform.tfvars Template

Create this file with your actual values:

```bash
# Copy the example and fill in your details
cd /Users/dmitrijsmeckers/Downloads/zaeb/breiq/terraform/
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
# ====================================
# YOUR BREIQ TERRAFORM CONFIGURATION
# ====================================

# AWS Configuration (REQUIRED)
aws_region  = "us-east-1"                    # Choose your region
aws_profile = "breiq"                        # Keep as "breiq"
environment = "production"                   # Keep as "production"

# Project Configuration
project_name = "breiq"                       # Keep as "breiq"
domain_name  = "breiq.online"               # Keep default for now

# Contact Information (REQUIRED - USE YOUR EMAIL)
alert_email = "YOUR_EMAIL@gmail.com"        # ⚠️ CHANGE THIS TO YOUR EMAIL

# Database Configuration (Good defaults)
db_instance_class         = "db.t4g.medium" # Good starting size
db_backup_retention_days  = 7               # 1 week backups
db_multi_az              = false            # Single AZ for cost savings

# Application Configuration (Good defaults)
ecs_cpu           = 512                     # 0.5 vCPU
ecs_memory        = 1024                    # 1GB RAM
ecs_desired_count = 2                       # 2 instances for reliability

# Personal Information (Optional)
additional_tags = {
  Owner       = "YourName"                  # ⚠️ CHANGE TO YOUR NAME
  CostCenter  = "Personal"
  Project     = "BreiqApp"
}
```

## 🚀 Step-by-Step Setup

### Step 1: Get AWS Credentials
```bash
# 1. Go to AWS Console (your personal account)
# 2. IAM → Users → Create User (if needed) → Security Credentials
# 3. Create Access Key for CLI
# 4. Save the keys securely
```

### Step 2: Configure AWS CLI
```bash
# Configure your personal AWS profile
aws configure --profile breiq

# Enter when prompted:
# AWS Access Key ID: [Your access key]
# AWS Secret Access Key: [Your secret key]  
# Default region: us-east-1
# Default output format: json
```

### Step 3: Verify Access
```bash
# Test your AWS access
aws sts get-caller-identity --profile breiq

# Should show your AWS Account ID and user info
```

### Step 4: Create Terraform Configuration
```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your email and name
nano terraform.tfvars
# or
code terraform.tfvars
```

### Step 5: Initialize Terraform
```bash
# Initialize Terraform
terraform init

# Preview what will be created
terraform plan

# Create the infrastructure
terraform apply
```

## 🔍 What If I Don't Have Some Settings?

### No Domain Name?
```hcl
# Just use the default, you'll get an ALB DNS like:
# breiq-production-alb-1234567890.us-east-1.elb.amazonaws.com
domain_name = "breiq.online"  # Keep default
```

### Not Sure About Instance Sizes?
```hcl
# Start small, you can scale up later
db_instance_class = "db.t4g.medium"    # ~$50/month
cache_node_type   = "cache.t4g.micro"  # ~$15/month
ecs_cpu           = 512                # ~$30/month
ecs_memory        = 1024
```

### Want to Save Money?
```hcl
# Minimal configuration for testing
db_instance_class = "db.t4g.micro"     # ~$15/month
cache_node_type   = "cache.t4g.micro"  # ~$15/month  
ecs_desired_count = 1                  # Single instance
```

## ⚠️ Important Notes

1. **Never commit terraform.tfvars to git** - it contains sensitive info
2. **Use your personal AWS account** - not your corporate account
3. **Start with default values** - you can modify later
4. **The only required changes are:**
   - Your email address (`alert_email`)
   - Your AWS credentials in CLI profile
   - Optionally your name in tags

## 🆘 Common Issues

**"Access Denied" error?**
- Make sure you're using your personal AWS account
- Check that your AWS CLI profile is configured correctly
- Verify your IAM user has AdministratorAccess policy

**"Region not found"?**
- Stick with `us-east-1` (cheapest and most reliable)

**Want to check costs first?**
```bash
# Use AWS Cost Calculator
# Estimate: db.t4g.medium (~$50) + ECS (~$30) + misc (~$20) = ~$100/month
```