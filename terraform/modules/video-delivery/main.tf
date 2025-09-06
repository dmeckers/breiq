# ====================================
# VIDEO DELIVERY MODULE
# Instagram-style video streaming infrastructure
# ====================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ====================================
# VARIABLES
# ====================================

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "bucket_suffix" {
  description = "Random suffix for bucket names"
  type        = string
}

variable "cors_origins" {
  description = "CORS origins for video access"
  type        = list(string)
}

variable "video_profiles" {
  description = "Video quality profiles"
  type = map(object({
    width   = number
    height  = number
    bitrate = string
  }))
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# ====================================
# S3 BUCKETS FOR VIDEO STORAGE
# ====================================

# Primary video storage bucket
resource "aws_s3_bucket" "video_storage" {
  bucket = "${var.project_name}-videos-${var.bucket_suffix}"
  tags   = var.tags
}

# Raw video uploads (before processing)
resource "aws_s3_bucket" "video_uploads" {
  bucket = "${var.project_name}-uploads-${var.bucket_suffix}"
  tags   = var.tags
}

# Processed video outputs (multiple qualities)
resource "aws_s3_bucket" "video_processed" {
  bucket = "${var.project_name}-processed-${var.bucket_suffix}"
  tags   = var.tags
}

# Thumbnail storage
resource "aws_s3_bucket" "thumbnails" {
  bucket = "${var.project_name}-thumbnails-${var.bucket_suffix}"
  tags   = var.tags
}

# ====================================
# S3 BUCKET CONFIGURATIONS
# ====================================

# Video storage bucket versioning
resource "aws_s3_bucket_versioning" "video_storage" {
  bucket = aws_s3_bucket.video_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Video storage bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "video_storage" {
  bucket = aws_s3_bucket.video_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Public access block for security
resource "aws_s3_bucket_public_access_block" "video_storage" {
  bucket = aws_s3_bucket.video_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CORS configuration for video access
resource "aws_s3_bucket_cors_configuration" "video_storage" {
  bucket = aws_s3_bucket.video_storage.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = var.cors_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3600
  }
}

# Lifecycle policy for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "video_storage" {
  bucket = aws_s3_bucket.video_storage.id

  rule {
    id     = "video_lifecycle"
    status = "Enabled"

    # Move older videos to cheaper storage
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Keep versions for 30 days then delete
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# ====================================
# CLOUDFRONT DISTRIBUTION
# Instagram-level global CDN
# ====================================

resource "aws_cloudfront_origin_access_control" "video_oac" {
  name                              = "${var.project_name}-video-oac"
  description                       = "OAC for video delivery"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "video_cdn" {
  # Multiple origins for different content types
  origin {
    domain_name              = aws_s3_bucket.video_storage.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.video_storage.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.video_oac.id
  }

  origin {
    domain_name              = aws_s3_bucket.thumbnails.bucket_regional_domain_name
    origin_id                = "S3-thumbnails"
    origin_access_control_id = aws_cloudfront_origin_access_control.video_oac.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Breiq video delivery CDN"
  default_root_object = ""

  # Instagram-style caching for videos
  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.video_storage.id}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = true
      headers      = ["Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method"]
      
      cookies {
        forward = "none"
      }
    }

    # Optimized caching for video content
    min_ttl     = 0
    default_ttl = 86400   # 1 day
    max_ttl     = 31536000 # 1 year
  }

  # Separate cache behavior for thumbnails (more aggressive caching)
  ordered_cache_behavior {
    path_pattern           = "/thumbnails/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-thumbnails"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 604800   # 1 week
    max_ttl     = 31536000 # 1 year
  }

  # Global edge locations for Instagram-level performance
  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # SSL certificate
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  # Custom error pages
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/404.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/404.html"
  }

  tags = var.tags
}

# ====================================
# S3 BUCKET POLICY FOR CLOUDFRONT
# ====================================

data "aws_iam_policy_document" "s3_policy" {
  statement {
    sid    = "AllowCloudFrontServicePrincipal"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.video_storage.arn}/*",
      "${aws_s3_bucket.thumbnails.arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.video_cdn.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "video_storage_policy" {
  bucket = aws_s3_bucket.video_storage.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

resource "aws_s3_bucket_policy" "thumbnails_policy" {
  bucket = aws_s3_bucket.thumbnails.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

# ====================================
# MEDIACONVERT FOR VIDEO PROCESSING
# Instagram-style video processing
# ====================================

# IAM role for MediaConvert
resource "aws_iam_role" "mediaconvert_role" {
  name = "${var.project_name}-mediaconvert-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "mediaconvert.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Policy for MediaConvert to access S3
resource "aws_iam_role_policy" "mediaconvert_policy" {
  name = "${var.project_name}-mediaconvert-policy"
  role = aws_iam_role.mediaconvert_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.video_uploads.arn}/*",
          "${aws_s3_bucket.video_processed.arn}/*",
          "${aws_s3_bucket.thumbnails.arn}/*"
        ]
      }
    ]
  })
}

# ====================================
# LAMBDA FOR VIDEO PROCESSING TRIGGER
# ====================================

resource "aws_iam_role" "video_processor_lambda_role" {
  name = "${var.project_name}-video-processor-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.video_processor_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_mediaconvert_policy" {
  name = "${var.project_name}-lambda-mediaconvert"
  role = aws_iam_role.video_processor_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "mediaconvert:*",
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "*"
      }
    ]
  })
}

# ====================================
# OUTPUTS
# ====================================

output "cloudfront_domain" {
  description = "CloudFront distribution domain"
  value       = aws_cloudfront_distribution.video_cdn.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.video_cdn.id
}

output "video_bucket_name" {
  description = "Video storage bucket name"
  value       = aws_s3_bucket.video_storage.bucket
}

output "upload_bucket_name" {
  description = "Upload bucket name"
  value       = aws_s3_bucket.video_uploads.bucket
}

output "thumbnails_bucket_name" {
  description = "Thumbnails bucket name"
  value       = aws_s3_bucket.thumbnails.bucket
}

output "mediaconvert_role_arn" {
  description = "MediaConvert IAM role ARN"
  value       = aws_iam_role.mediaconvert_role.arn
}