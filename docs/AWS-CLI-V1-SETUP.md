# AWS CLI v1 Setup for Multi-Account Management

## Setting Up Named Profiles for AWS CLI v1

Since you're using AWS CLI v1, here are the specific commands to configure your personal Breiq account alongside your existing corporate account.

### 1. Configure Your Personal Breiq Profile

```bash
# Configure the breiq profile for your personal AWS account
aws configure --profile breiq

# You'll be prompted for:
# AWS Access Key ID [None]: YOUR_PERSONAL_ACCESS_KEY
# AWS Secret Access Key [None]: YOUR_PERSONAL_SECRET_KEY
# Default region name [None]: us-east-1
# Default output format [None]: json
```

### 2. Verify Profile Configuration

```bash
# Check your configured profiles
cat ~/.aws/credentials

# Should show something like:
# [default]          # Your corporate account
# aws_access_key_id = CORPORATE_KEY
# aws_secret_access_key = CORPORATE_SECRET
# 
# [breiq]            # Your personal account
# aws_access_key_id = PERSONAL_KEY
# aws_secret_access_key = PERSONAL_SECRET
```

### 3. Test Profile Access

```bash
# Test corporate account (default)
aws sts get-caller-identity

# Test personal account (breiq profile)
aws sts get-caller-identity --profile breiq
```

The output should show different Account IDs, confirming you can access both accounts.

### 4. Set Profile for Current Session

For AWS CLI v1, you can set the profile for your current terminal session:

```bash
# Option 1: Set environment variable
export AWS_PROFILE=breiq

# Option 2: Always use --profile flag
aws s3 ls --profile breiq
```

### 5. Terraform Configuration

Your Terraform configuration is already set up to use the `breiq` profile. To deploy:

```bash
# Navigate to terraform directory
cd terraform/

# Initialize Terraform (will use breiq profile)
terraform init

# Plan deployment
terraform plan -var="aws_profile=breiq"

# Apply infrastructure
terraform apply -var="aws_profile=breiq"
```

### 6. Laravel Deployment Script

The deployment script supports AWS CLI v1 with the profile parameter:

```bash
# Navigate to scripts directory
cd scripts/

# Deploy with breiq profile
./deploy-laravel.sh staging us-east-1 breiq
```

### 7. Switching Between Accounts

```bash
# For corporate work
export AWS_PROFILE=default
# or don't set AWS_PROFILE at all

# For Breiq work
export AWS_PROFILE=breiq

# Verify current account
aws sts get-caller-identity
```

### 8. AWS CLI v1 vs v2 Key Differences

Since you're using v1, note these differences:

```bash
# v1: Configure with --profile
aws configure --profile breiq

# v2: Would be the same
aws configure --profile breiq

# v1: Environment variable
export AWS_PROFILE=breiq

# v2: Same
export AWS_PROFILE=breiq

# v1: ECR login (your current version)
aws ecr get-login --no-include-email --region us-east-1 --profile breiq | sh

# v2: Would be different
aws ecr get-login-password --region us-east-1 --profile breiq | docker login --username AWS --password-stdin
```

## Next Steps

1. Configure the `breiq` profile with your personal AWS credentials
2. Test access to both accounts
3. Run `terraform init` and `terraform apply` with the breiq profile
4. Deploy your Laravel backend using the deployment script

This setup ensures your corporate and personal AWS accounts remain completely separate.