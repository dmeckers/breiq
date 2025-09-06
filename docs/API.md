# Breiq API Documentation

## 🎯 API Overview

The Breiq API provides comprehensive endpoints for a video sharing platform with Instagram-level performance and features. This RESTful API supports video uploads, user management, social features, and real-time interactions.

## 🏗️ API Architecture

### Base URL
- **Production**: `https://api.breiq.com/api/v1`
- **Staging**: `https://staging-api.breiq.com/api/v1`
- **Development**: `http://localhost:8000/api/v1`

### Response Format
```json
{
  "success": true,
  "data": {},
  "message": "Request successful",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "request_id": "req_abc123"
}
```

### Error Format
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input parameters",
    "details": [
      {
        "field": "email",
        "message": "Invalid email format"
      }
    ]
  },
  "timestamp": "2024-01-15T10:30:00.000Z",
  "request_id": "req_abc123"
}
```

## 🔐 Authentication

### JWT Authentication
```http
Authorization: Bearer <access_token>
```

### Token Refresh
```http
POST /api/v1/auth/refresh
Content-Type: application/json

{
  "refresh_token": "refresh_token_here"
}
```

### Response
```json
{
  "success": true,
  "data": {
    "access_token": "new_access_token",
    "refresh_token": "new_refresh_token",
    "expires_in": 900
  }
}
```

## 👤 User Management

### Register User
```http
POST /api/v1/auth/register
Content-Type: application/json

{
  "username": "johndoe",
  "email": "john@example.com",
  "password": "SecurePass123!",
  "full_name": "John Doe",
  "date_of_birth": "1990-05-15"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "uuid-123",
      "username": "johndoe",
      "email": "john@example.com",
      "full_name": "John Doe",
      "profile_image_url": null,
      "bio": null,
      "followers_count": 0,
      "following_count": 0,
      "videos_count": 0,
      "is_verified": false,
      "created_at": "2024-01-15T10:30:00.000Z"
    },
    "access_token": "jwt_token_here",
    "refresh_token": "refresh_token_here",
    "expires_in": 900
  }
}
```

### Login User
```http
POST /api/v1/auth/login
Content-Type: application/json

{
  "email": "john@example.com",
  "password": "SecurePass123!"
}
```

### Get User Profile
```http
GET /api/v1/users/profile
Authorization: Bearer <access_token>
```

### Update User Profile
```http
PATCH /api/v1/users/profile
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "full_name": "John Doe Updated",
  "bio": "Video creator and tech enthusiast",
  "profile_image_url": "https://cdn.breiq.com/profiles/user123.jpg"
}
```

### Get User by Username
```http
GET /api/v1/users/@johndoe
```

### Get User Statistics
```http
GET /api/v1/users/stats
Authorization: Bearer <access_token>
```

**Response:**
```json
{
  "success": true,
  "data": {
    "total_views": 50000,
    "total_likes": 5000,
    "total_comments": 1200,
    "total_shares": 800,
    "videos_count": 25,
    "followers_count": 1500,
    "following_count": 200,
    "engagement_rate": 12.5,
    "average_views_per_video": 2000
  }
}
```

## 🎬 Video Management

### Upload Video
```http
POST /api/v1/videos/upload
Authorization: Bearer <access_token>
Content-Type: multipart/form-data

Form Fields:
- video: (file) Video file
- title: (string) Video title
- description: (string) Video description
- tags: (string) Comma-separated tags
- thumbnail: (file) Optional custom thumbnail
- is_public: (boolean) Video visibility
```

**Response:**
```json
{
  "success": true,
  "data": {
    "video": {
      "id": "video_uuid_123",
      "title": "Amazing Sunset Timelapse",
      "description": "Beautiful sunset captured in 4K",
      "video_url": "https://cdn.breiq.com/videos/video_uuid_123/index.m3u8",
      "thumbnail_url": "https://cdn.breiq.com/thumbnails/video_uuid_123.jpg",
      "duration": 120,
      "file_size": 45000000,
      "resolution": "1920x1080",
      "format": "mp4",
      "processing_status": "processing",
      "is_public": true,
      "tags": ["sunset", "nature", "timelapse"],
      "created_at": "2024-01-15T10:30:00.000Z",
      "user": {
        "id": "user_uuid",
        "username": "johndoe",
        "profile_image_url": "https://cdn.breiq.com/profiles/user123.jpg"
      },
      "stats": {
        "views_count": 0,
        "likes_count": 0,
        "comments_count": 0,
        "shares_count": 0
      }
    },
    "upload_id": "upload_123",
    "estimated_processing_time": 300
  }
}
```

### Get Video
```http
GET /api/v1/videos/:videoId
```

### Update Video
```http
PATCH /api/v1/videos/:videoId
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "title": "Updated Video Title",
  "description": "Updated description",
  "is_public": false,
  "tags": ["updated", "video", "content"]
}
```

### Delete Video
```http
DELETE /api/v1/videos/:videoId
Authorization: Bearer <access_token>
```

### Get User Videos
```http
GET /api/v1/users/:userId/videos?page=1&limit=20&sort=created_at&order=desc
```

### Search Videos
```http
GET /api/v1/videos/search?q=sunset&tags=nature,landscape&duration_min=60&duration_max=300&page=1&limit=20
```

**Response:**
```json
{
  "success": true,
  "data": {
    "videos": [...],
    "pagination": {
      "current_page": 1,
      "total_pages": 10,
      "total_count": 200,
      "limit": 20,
      "has_next": true,
      "has_prev": false
    },
    "filters_applied": {
      "query": "sunset",
      "tags": ["nature", "landscape"],
      "duration_range": "60-300"
    }
  }
}
```

### Get Trending Videos
```http
GET /api/v1/videos/trending?timeframe=week&category=all&limit=50
```

### Get Video Processing Status
```http
GET /api/v1/videos/:videoId/status
Authorization: Bearer <access_token>
```

**Response:**
```json
{
  "success": true,
  "data": {
    "video_id": "video_uuid_123",
    "processing_status": "completed",
    "progress_percentage": 100,
    "estimated_completion": null,
    "available_qualities": ["1080p", "720p", "480p", "360p"],
    "thumbnail_generated": true,
    "hls_ready": true,
    "error_message": null
  }
}
```

## ❤️ Social Features

### Like Video
```http
POST /api/v1/videos/:videoId/like
Authorization: Bearer <access_token>
```

### Unlike Video
```http
DELETE /api/v1/videos/:videoId/like
Authorization: Bearer <access_token>
```

### Comment on Video
```http
POST /api/v1/videos/:videoId/comments
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "content": "Great video! Love the cinematography.",
  "parent_id": null
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "comment": {
      "id": "comment_uuid_123",
      "content": "Great video! Love the cinematography.",
      "likes_count": 0,
      "replies_count": 0,
      "created_at": "2024-01-15T10:30:00.000Z",
      "updated_at": "2024-01-15T10:30:00.000Z",
      "user": {
        "id": "user_uuid",
        "username": "johndoe",
        "profile_image_url": "https://cdn.breiq.com/profiles/user123.jpg"
      },
      "parent_id": null,
      "is_liked": false
    }
  }
}
```

### Get Video Comments
```http
GET /api/v1/videos/:videoId/comments?page=1&limit=20&sort=created_at&order=desc
```

### Reply to Comment
```http
POST /api/v1/videos/:videoId/comments
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "content": "Thanks for the kind words!",
  "parent_id": "comment_uuid_123"
}
```

### Like Comment
```http
POST /api/v1/comments/:commentId/like
Authorization: Bearer <access_token>
```

### Update Comment
```http
PATCH /api/v1/comments/:commentId
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "content": "Updated comment content"
}
```

### Delete Comment
```http
DELETE /api/v1/comments/:commentId
Authorization: Bearer <access_token>
```

### Follow User
```http
POST /api/v1/users/:userId/follow
Authorization: Bearer <access_token>
```

### Unfollow User
```http
DELETE /api/v1/users/:userId/follow
Authorization: Bearer <access_token>
```

### Get User Followers
```http
GET /api/v1/users/:userId/followers?page=1&limit=50
```

### Get User Following
```http
GET /api/v1/users/:userId/following?page=1&limit=50
```

### Share Video
```http
POST /api/v1/videos/:videoId/share
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "platform": "twitter",
  "message": "Check out this amazing video!"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "share_id": "share_uuid_123",
    "share_url": "https://breiq.com/v/video_uuid_123",
    "platform": "twitter",
    "created_at": "2024-01-15T10:30:00.000Z"
  }
}
```

## 📱 Feed & Discovery

### Get User Feed
```http
GET /api/v1/feed?page=1&limit=20
Authorization: Bearer <access_token>
```

**Response:**
```json
{
  "success": true,
  "data": {
    "feed_items": [
      {
        "id": "feed_item_123",
        "type": "video",
        "video": {
          "id": "video_uuid",
          "title": "Amazing Video",
          "thumbnail_url": "...",
          "duration": 120,
          "user": {...},
          "stats": {...}
        },
        "reason": "following",
        "created_at": "2024-01-15T10:30:00.000Z"
      }
    ],
    "pagination": {...},
    "refresh_token": "feed_refresh_token"
  }
}
```

### Get Explore Feed
```http
GET /api/v1/explore?category=trending&location=global&page=1&limit=20
```

### Get Personalized Recommendations
```http
GET /api/v1/recommendations?type=videos&limit=10
Authorization: Bearer <access_token>
```

## 🔔 Notifications

### Get Notifications
```http
GET /api/v1/notifications?page=1&limit=20&type=all&read=false
Authorization: Bearer <access_token>
```

**Response:**
```json
{
  "success": true,
  "data": {
    "notifications": [
      {
        "id": "notification_123",
        "type": "like",
        "title": "New like on your video",
        "message": "johndoe liked your video 'Amazing Sunset'",
        "is_read": false,
        "created_at": "2024-01-15T10:30:00.000Z",
        "data": {
          "video_id": "video_uuid",
          "user_id": "user_uuid",
          "action": "like"
        },
        "actor": {
          "id": "user_uuid",
          "username": "johndoe",
          "profile_image_url": "..."
        }
      }
    ],
    "unread_count": 5,
    "pagination": {...}
  }
}
```

### Mark Notification as Read
```http
PATCH /api/v1/notifications/:notificationId
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "is_read": true
}
```

### Mark All Notifications as Read
```http
PATCH /api/v1/notifications/read-all
Authorization: Bearer <access_token>
```

### Get Notification Settings
```http
GET /api/v1/notifications/settings
Authorization: Bearer <access_token>
```

### Update Notification Settings
```http
PATCH /api/v1/notifications/settings
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "email_notifications": true,
  "push_notifications": true,
  "notification_types": {
    "likes": true,
    "comments": true,
    "follows": true,
    "mentions": false
  }
}
```

## 🔍 Search & Discovery

### Global Search
```http
GET /api/v1/search?q=sunset&type=all&page=1&limit=20
```

### Search Users
```http
GET /api/v1/search/users?q=john&verified=false&followers_min=100&page=1&limit=20
```

### Search Videos
```http
GET /api/v1/search/videos?q=tutorial&duration_min=300&quality=hd&uploaded_after=2024-01-01&page=1&limit=20
```

### Get Search Suggestions
```http
GET /api/v1/search/suggestions?q=suns
```

**Response:**
```json
{
  "success": true,
  "data": {
    "suggestions": [
      {
        "text": "sunset",
        "type": "tag",
        "count": 1250
      },
      {
        "text": "sunshine",
        "type": "tag",
        "count": 800
      },
      {
        "text": "@sunsetphotographer",
        "type": "user",
        "user": {
          "username": "sunsetphotographer",
          "profile_image_url": "..."
        }
      }
    ]
  }
}
```

### Get Popular Tags
```http
GET /api/v1/tags/popular?limit=50&timeframe=week
```

## 📊 Analytics & Insights

### Get Video Analytics
```http
GET /api/v1/videos/:videoId/analytics?timeframe=7d
Authorization: Bearer <access_token>
```

**Response:**
```json
{
  "success": true,
  "data": {
    "video_id": "video_uuid_123",
    "timeframe": "7d",
    "metrics": {
      "total_views": 5000,
      "unique_views": 4200,
      "likes": 500,
      "comments": 150,
      "shares": 75,
      "completion_rate": 68.5,
      "average_watch_time": 45,
      "engagement_rate": 14.5
    },
    "demographics": {
      "age_groups": {
        "18-24": 35,
        "25-34": 40,
        "35-44": 20,
        "45+": 5
      },
      "countries": {
        "US": 45,
        "UK": 15,
        "CA": 10,
        "others": 30
      },
      "devices": {
        "mobile": 75,
        "desktop": 20,
        "tablet": 5
      }
    },
    "daily_stats": [
      {
        "date": "2024-01-15",
        "views": 800,
        "likes": 80,
        "comments": 25
      }
    ]
  }
}
```

### Get User Analytics
```http
GET /api/v1/users/analytics?timeframe=30d
Authorization: Bearer <access_token>
```

### Get Channel Insights
```http
GET /api/v1/users/insights?metrics=growth,engagement,revenue&timeframe=90d
Authorization: Bearer <access_token>
```

## 🎥 Video Processing & Streaming

### Get Video Formats
```http
GET /api/v1/videos/:videoId/formats
```

**Response:**
```json
{
  "success": true,
  "data": {
    "video_id": "video_uuid_123",
    "formats": [
      {
        "quality": "1080p",
        "format": "mp4",
        "url": "https://cdn.breiq.com/videos/video_uuid_123/1080p.mp4",
        "file_size": 45000000,
        "bitrate": 5000
      },
      {
        "quality": "720p",
        "format": "mp4", 
        "url": "https://cdn.breiq.com/videos/video_uuid_123/720p.mp4",
        "file_size": 25000000,
        "bitrate": 2500
      }
    ],
    "hls_url": "https://cdn.breiq.com/videos/video_uuid_123/index.m3u8",
    "dash_url": "https://cdn.breiq.com/videos/video_uuid_123/index.mpd"
  }
}
```

### Get Video Metrics
```http
GET /api/v1/videos/:videoId/metrics
Authorization: Bearer <access_token>
```

### Update Video View
```http
POST /api/v1/videos/:videoId/view
Content-Type: application/json

{
  "watch_time": 45,
  "quality": "720p",
  "device": "mobile",
  "location": {
    "country": "US",
    "city": "New York"
  }
}
```

## 🔴 Live Streaming

### Create Live Stream
```http
POST /api/v1/live/streams
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "title": "Live Stream Title",
  "description": "Live stream description",
  "tags": ["live", "streaming"],
  "is_public": true,
  "scheduled_start": "2024-01-15T15:00:00.000Z"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "stream": {
      "id": "stream_uuid_123",
      "title": "Live Stream Title",
      "description": "Live stream description",
      "status": "scheduled",
      "rtmp_url": "rtmp://live.breiq.com/live",
      "stream_key": "stream_key_secret_123",
      "playback_url": "https://cdn.breiq.com/live/stream_uuid_123/index.m3u8",
      "scheduled_start": "2024-01-15T15:00:00.000Z",
      "created_at": "2024-01-15T10:30:00.000Z",
      "viewer_count": 0,
      "max_viewers": 0
    }
  }
}
```

### Start Live Stream
```http
PATCH /api/v1/live/streams/:streamId/start
Authorization: Bearer <access_token>
```

### End Live Stream
```http
PATCH /api/v1/live/streams/:streamId/end
Authorization: Bearer <access_token>
```

### Get Live Stream
```http
GET /api/v1/live/streams/:streamId
```

### Get Live Streams
```http
GET /api/v1/live/streams?status=live&page=1&limit=20
```

### Get Stream Chat Messages
```http
GET /api/v1/live/streams/:streamId/chat?page=1&limit=50
Authorization: Bearer <access_token>
```

## 📱 Mobile & PWA Features

### Upload Progress Tracking
```http
GET /api/v1/uploads/:uploadId/progress
Authorization: Bearer <access_token>
```

**Response:**
```json
{
  "success": true,
  "data": {
    "upload_id": "upload_123",
    "status": "uploading",
    "progress_percentage": 75,
    "bytes_uploaded": 37500000,
    "total_bytes": 50000000,
    "estimated_completion": "2024-01-15T10:35:00.000Z",
    "error_message": null
  }
}
```

### Device Registration (Push Notifications)
```http
POST /api/v1/devices/register
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "device_token": "fcm_token_here",
  "device_type": "ios",
  "app_version": "1.0.0",
  "os_version": "15.0"
}
```

### Offline Content
```http
POST /api/v1/videos/:videoId/download
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "quality": "720p",
  "device_id": "device_uuid_123"
}
```

## 🔧 Admin & Moderation

### Get Content Reports
```http
GET /api/v1/admin/reports?type=video&status=pending&page=1&limit=20
Authorization: Bearer <admin_access_token>
```

### Moderate Content
```http
PATCH /api/v1/admin/videos/:videoId/moderate
Authorization: Bearer <admin_access_token>
Content-Type: application/json

{
  "action": "remove",
  "reason": "inappropriate_content",
  "note": "Contains inappropriate material"
}
```

### Get System Metrics
```http
GET /api/v1/admin/metrics?timeframe=24h
Authorization: Bearer <admin_access_token>
```

## 📈 Rate Limiting

### Rate Limits
```yaml
Default Limits:
  - General API: 1000 requests/hour per user
  - Upload API: 10 uploads/hour per user
  - Search API: 100 requests/minute per user
  - Anonymous: 100 requests/hour per IP
  
Premium Limits:
  - General API: 5000 requests/hour per user
  - Upload API: 50 uploads/hour per user
  - Search API: 500 requests/minute per user
```

### Rate Limit Headers
```http
HTTP/1.1 200 OK
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1642248000
X-RateLimit-Retry-After: 3600
```

## 🔄 WebSocket Events

### Connection
```javascript
const socket = io('wss://api.breiq.com', {
  auth: {
    token: 'access_token_here'
  }
});
```

### Video Events
```javascript
// Video upload progress
socket.on('upload:progress', (data) => {
  console.log('Upload progress:', data.percentage);
});

// Video processing complete
socket.on('video:processed', (data) => {
  console.log('Video ready:', data.video_id);
});

// New like on video
socket.on('video:like', (data) => {
  console.log('New like from:', data.user.username);
});
```

### Live Stream Events
```javascript
// Viewer joined stream
socket.on('stream:viewer_joined', (data) => {
  console.log('New viewer:', data.viewer_count);
});

// Chat message
socket.on('stream:chat_message', (data) => {
  console.log('Chat:', data.message);
});
```

### Notification Events
```javascript
// Real-time notification
socket.on('notification:new', (data) => {
  console.log('New notification:', data);
});
```

## 📋 Error Codes

### HTTP Status Codes
```yaml
Success Codes:
  200: OK - Request successful
  201: Created - Resource created successfully
  204: No Content - Request successful, no content returned

Client Error Codes:
  400: Bad Request - Invalid request parameters
  401: Unauthorized - Authentication required
  403: Forbidden - Access denied
  404: Not Found - Resource not found
  409: Conflict - Resource conflict
  413: Payload Too Large - File too large
  422: Unprocessable Entity - Validation failed
  429: Too Many Requests - Rate limit exceeded

Server Error Codes:
  500: Internal Server Error - Server error
  502: Bad Gateway - Upstream server error
  503: Service Unavailable - Service temporarily unavailable
  504: Gateway Timeout - Request timeout
```

### Custom Error Codes
```yaml
Authentication Errors:
  AUTH_001: Invalid credentials
  AUTH_002: Token expired
  AUTH_003: Token malformed
  AUTH_004: Account suspended
  
Validation Errors:
  VAL_001: Required field missing
  VAL_002: Invalid field format
  VAL_003: Field value out of range
  VAL_004: Duplicate value
  
Resource Errors:
  RES_001: Video not found
  RES_002: User not found
  RES_003: Comment not found
  RES_004: Permission denied
  
Upload Errors:
  UPL_001: File too large
  UPL_002: Invalid file format
  UPL_003: Upload timeout
  UPL_004: Processing failed
```

## 🧪 Testing

### API Testing Examples

#### cURL Examples
```bash
# Register user
curl -X POST https://api.breiq.com/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "SecurePass123!"
  }'

# Upload video
curl -X POST https://api.breiq.com/api/v1/videos/upload \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -F "video=@video.mp4" \
  -F "title=Test Video" \
  -F "description=Test video description"
```

#### JavaScript/Node.js Example
```javascript
const axios = require('axios');

// API client setup
const apiClient = axios.create({
  baseURL: 'https://api.breiq.com/api/v1',
  headers: {
    'Content-Type': 'application/json'
  }
});

// Add auth interceptor
apiClient.interceptors.request.use((config) => {
  const token = localStorage.getItem('access_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Upload video
async function uploadVideo(file, metadata) {
  const formData = new FormData();
  formData.append('video', file);
  formData.append('title', metadata.title);
  formData.append('description', metadata.description);
  
  try {
    const response = await apiClient.post('/videos/upload', formData, {
      headers: { 'Content-Type': 'multipart/form-data' }
    });
    return response.data;
  } catch (error) {
    console.error('Upload failed:', error.response?.data);
    throw error;
  }
}
```

---

*API Documentation Version: 1.0.0*  
*Last Updated: 2024-01-15*  
*For support, contact: api-support@breiq.com*