# ====================================
# AWS MEDIA SERVICES FOR REELS STREAMING
# Instagram-like video processing and streaming
# ====================================

# ====================================
# ADDITIONAL S3 BUCKETS FOR MEDIA PROCESSING
# ====================================

# Processed videos bucket (HLS output)
resource "aws_s3_bucket" "processed_videos" {
  bucket = "${var.project_name}-${var.environment}-processed-${random_string.bucket_suffix.result}"

  tags = {
    Name = "${var.project_name}-${var.environment}-processed-videos"
  }
}

resource "aws_s3_bucket_public_access_block" "processed_videos" {
  bucket = aws_s3_bucket.processed_videos.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_cors_configuration" "processed_videos" {
  bucket = aws_s3_bucket.processed_videos.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3600
  }
}

# Thumbnails bucket
resource "aws_s3_bucket" "thumbnails" {
  bucket = "${var.project_name}-${var.environment}-thumbnails-${random_string.bucket_suffix.result}"

  tags = {
    Name = "${var.project_name}-${var.environment}-thumbnails"
  }
}

resource "aws_s3_bucket_public_access_block" "thumbnails" {
  bucket = aws_s3_bucket.thumbnails.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# ====================================
# MEDIACONVERT SERVICE ROLE
# ====================================

resource "aws_iam_role" "mediaconvert_role" {
  name = "${var.project_name}-${var.environment}-mediaconvert-role"

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

  tags = {
    Name = "${var.project_name}-${var.environment}-mediaconvert-role"
  }
}

resource "aws_iam_role_policy" "mediaconvert_policy" {
  name = "${var.project_name}-${var.environment}-mediaconvert-policy"
  role = aws_iam_role.mediaconvert_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.videos.arn,
          "${aws_s3_bucket.videos.arn}/*",
          aws_s3_bucket.processed_videos.arn,
          "${aws_s3_bucket.processed_videos.arn}/*",
          aws_s3_bucket.thumbnails.arn,
          "${aws_s3_bucket.thumbnails.arn}/*"
        ]
      }
    ]
  })
}

# ====================================
# LAMBDA FUNCTION FOR VIDEO PROCESSING
# ====================================

# Create Lambda deployment package
data "archive_file" "video_processor" {
  type        = "zip"
  output_path = "/tmp/video_processor.zip"
  
  source {
    content = <<EOF
import boto3
import json
import uuid

def lambda_handler(event, context):
    """
    Process S3 video upload events and trigger MediaConvert jobs
    """
    
    mediaconvert = boto3.client('mediaconvert', region_name='${var.aws_region}')
    
    # Get MediaConvert endpoint
    endpoints = mediaconvert.describe_endpoints()
    endpoint_url = endpoints['Endpoints'][0]['Url']
    
    # Create MediaConvert client with endpoint
    mc_client = boto3.client('mediaconvert', endpoint_url=endpoint_url)
    
    for record in event.get('Records', []):
        if record['eventName'].startswith('ObjectCreated'):
            bucket = record['s3']['bucket']['name']
            key = record['s3']['object']['key']
            
            # Only process video files in raw-videos/ folder
            if not key.startswith('raw-videos/') or not key.lower().endswith(('.mp4', '.mov', '.avi')):
                continue
            
            # Extract video ID from filename
            video_id = key.split('/')[-1].split('.')[0]
            
            # Create MediaConvert job
            job_settings = {
                "Role": "${aws_iam_role.mediaconvert_role.arn}",
                "Settings": {
                    "Inputs": [{
                        "FileInput": f"s3://{bucket}/{key}",
                        "AudioSelectors": {
                            "Audio Selector 1": {
                                "Offset": 0,
                                "DefaultSelection": "DEFAULT",
                                "ProgramSelection": 1
                            }
                        },
                        "VideoSelector": {
                            "ColorSpace": "FOLLOW"
                        }
                    }],
                    "OutputGroups": [
                        {
                            "Name": "HLS",
                            "OutputGroupSettings": {
                                "Type": "HLS_GROUP_SETTINGS",
                                "HlsGroupSettings": {
                                    "Destination": "s3://${aws_s3_bucket.processed_videos.bucket}/hls/" + video_id + "/",
                                    "SegmentLength": 6,
                                    "MinSegmentLength": 0
                                }
                            },
                            "Outputs": [
                                {
                                    "NameModifier": "_720p",
                                    "VideoDescription": {
                                        "Width": 1280,
                                        "Height": 720,
                                        "CodecSettings": {
                                            "Codec": "H_264",
                                            "H264Settings": {
                                                "Bitrate": 2000000,
                                                "RateControlMode": "CBR"
                                            }
                                        }
                                    },
                                    "AudioDescriptions": [{
                                        "AudioTypeControl": "FOLLOW_INPUT",
                                        "CodecSettings": {
                                            "Codec": "AAC",
                                            "AacSettings": {
                                                "AudioDescriptionBroadcasterMix": "NORMAL",
                                                "Bitrate": 96000,
                                                "RateControlMode": "CBR",
                                                "CodecProfile": "LC",
                                                "CodingMode": "CODING_MODE_2_0",
                                                "SampleRate": 48000
                                            }
                                        }
                                    }]
                                },
                                {
                                    "NameModifier": "_480p",
                                    "VideoDescription": {
                                        "Width": 854,
                                        "Height": 480,
                                        "CodecSettings": {
                                            "Codec": "H_264",
                                            "H264Settings": {
                                                "Bitrate": 1000000,
                                                "RateControlMode": "CBR"
                                            }
                                        }
                                    },
                                    "AudioDescriptions": [{
                                        "AudioTypeControl": "FOLLOW_INPUT",
                                        "CodecSettings": {
                                            "Codec": "AAC",
                                            "AacSettings": {
                                                "AudioDescriptionBroadcasterMix": "NORMAL",
                                                "Bitrate": 96000,
                                                "RateControlMode": "CBR",
                                                "CodecProfile": "LC",
                                                "CodingMode": "CODING_MODE_2_0",
                                                "SampleRate": 48000
                                            }
                                        }
                                    }]
                                }
                            ]
                        },
                        {
                            "Name": "Thumbnails",
                            "OutputGroupSettings": {
                                "Type": "FILE_GROUP_SETTINGS",
                                "FileGroupSettings": {
                                    "Destination": "s3://${aws_s3_bucket.thumbnails.bucket}/thumbs/" + video_id + "/"
                                }
                            },
                            "Outputs": [{
                                "NameModifier": "_thumb",
                                "VideoDescription": {
                                    "Width": 320,
                                    "Height": 180,
                                    "CodecSettings": {
                                        "Codec": "FRAME_CAPTURE",
                                        "FrameCaptureSettings": {
                                            "FramerateNumerator": 1,
                                            "FramerateDenominator": 10,
                                            "MaxCaptures": 1,
                                            "Quality": 80
                                        }
                                    }
                                },
                                "ContainerSettings": {
                                    "Container": "RAW"
                                }
                            }]
                        }
                    ]
                }
            }
            
            response = mc_client.create_job(**job_settings)
            
            print(f"Created MediaConvert job for {key}: {response['Job']['Id']}")
    
    return {
        'statusCode': 200,
        'body': json.dumps('Video processing initiated')
    }
EOF
    filename = "lambda_function.py"
  }
}

# Lambda function
resource "aws_lambda_function" "video_processor" {
  filename         = data.archive_file.video_processor.output_path
  function_name    = "${var.project_name}-${var.environment}-video-processor"
  role            = aws_iam_role.lambda_exec_role.arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.video_processor.output_base64sha256
  runtime         = "python3.9"
  timeout         = 300

  environment {
    variables = {
      PROCESSED_BUCKET = aws_s3_bucket.processed_videos.bucket
      THUMBNAILS_BUCKET = aws_s3_bucket.thumbnails.bucket
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-video-processor"
  }
}

# Lambda execution role
resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.project_name}-${var.environment}-lambda-exec-role"

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

  tags = {
    Name = "${var.project_name}-${var.environment}-lambda-exec-role"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_mediaconvert_policy" {
  name = "${var.project_name}-${var.environment}-lambda-mediaconvert-policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "mediaconvert:*",
          "iam:PassRole"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.videos.arn,
          "${aws_s3_bucket.videos.arn}/*",
          aws_s3_bucket.processed_videos.arn,
          "${aws_s3_bucket.processed_videos.arn}/*",
          aws_s3_bucket.thumbnails.arn,
          "${aws_s3_bucket.thumbnails.arn}/*"
        ]
      }
    ]
  })
}

# S3 trigger for Lambda
resource "aws_s3_bucket_notification" "video_processing_trigger" {
  bucket = aws_s3_bucket.videos.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.video_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "raw-videos/"
    filter_suffix       = ""
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}

resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.video_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.videos.arn
}

# ====================================
# CLOUDFRONT DISTRIBUTION
# ====================================

resource "aws_cloudfront_origin_access_control" "processed_videos" {
  name                              = "${var.project_name}-${var.environment}-processed-videos-oac"
  description                       = "OAC for processed videos bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_origin_access_control" "thumbnails" {
  name                              = "${var.project_name}-${var.environment}-thumbnails-oac"
  description                       = "OAC for thumbnails bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "media_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = ""
  comment             = "${var.project_name} ${var.environment} media distribution"

  aliases = []

  # Processed videos origin (HLS streams)
  origin {
    domain_name              = aws_s3_bucket.processed_videos.bucket_regional_domain_name
    origin_id               = "processed-videos-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.processed_videos.id
  }

  # Thumbnails origin
  origin {
    domain_name              = aws_s3_bucket.thumbnails.bucket_regional_domain_name
    origin_id               = "thumbnails-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.thumbnails.id
  }

  # HLS video streaming behavior
  ordered_cache_behavior {
    path_pattern           = "/hls/*"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "processed-videos-origin"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      headers      = ["Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method"]
      
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }

  # Thumbnails behavior
  ordered_cache_behavior {
    path_pattern           = "/thumbs/*"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "thumbnails-origin"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }

  # Default behavior for processed videos
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "processed-videos-origin"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # Geographic restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # SSL certificate
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-media-distribution"
  }
}

# CloudFront bucket policies
resource "aws_s3_bucket_policy" "processed_videos_policy" {
  bucket = aws_s3_bucket.processed_videos.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.processed_videos.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.media_distribution.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "thumbnails_policy" {
  bucket = aws_s3_bucket.thumbnails.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.thumbnails.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.media_distribution.arn
          }
        }
      }
    ]
  })
}

# DNS record for media subdomain (disabled due to CNAME conflict)
# Will use CloudFront default domain for now

# ====================================
# OUTPUTS FOR MEDIA SERVICES
# ====================================

output "processed_videos_bucket" {
  description = "S3 bucket for processed videos (HLS)"
  value       = aws_s3_bucket.processed_videos.bucket
}

output "thumbnails_bucket" {
  description = "S3 bucket for video thumbnails"
  value       = aws_s3_bucket.thumbnails.bucket
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID for media delivery"
  value       = aws_cloudfront_distribution.media_distribution.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.media_distribution.domain_name
}

output "media_domain_url" {
  description = "CloudFront domain URL for media delivery"
  value       = "https://${aws_cloudfront_distribution.media_distribution.domain_name}"
}

output "lambda_function_name" {
  description = "Lambda function name for video processing"
  value       = aws_lambda_function.video_processor.function_name
}

output "mediaconvert_role_arn" {
  description = "MediaConvert service role ARN"
  value       = aws_iam_role.mediaconvert_role.arn
}