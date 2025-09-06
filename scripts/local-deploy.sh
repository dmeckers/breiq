#!/bin/bash

# Breiq Local Deployment Script
# Spins up the entire application stack locally for development

set -e

echo "🚀 Starting Breiq Local Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if Docker Compose is available
if ! command -v docker-compose &> /dev/null; then
    print_error "docker-compose not found. Please install Docker Compose."
    exit 1
fi

# Create docker-compose.yml for local development
print_status "Creating local Docker Compose configuration..."

cat > docker-compose.local.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: breiq_dev
      POSTGRES_USER: breiq_user
      POSTGRES_PASSWORD: breiq_pass
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./breiq-backend/database/init:/docker-entrypoint-initdb.d
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U breiq_user -d breiq_dev"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

  localstack:
    image: localstack/localstack:latest
    ports:
      - "4566:4566"
    environment:
      - SERVICES=s3,cloudfront,lambda
      - DEBUG=1
      - DOCKER_HOST=unix:///var/run/docker.sock
      - AWS_DEFAULT_REGION=us-east-1
      - AWS_ACCESS_KEY_ID=test
      - AWS_SECRET_ACCESS_KEY=test
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock"
      - localstack_data:/tmp/localstack

  backend:
    build:
      context: ./breiq-backend
      dockerfile: Dockerfile.dev
    ports:
      - "8000:8000"
    environment:
      - NODE_ENV=development
      - DATABASE_URL=postgresql://breiq_user:breiq_pass@postgres:5432/breiq_dev
      - REDIS_URL=redis://redis:6379
      - AWS_ENDPOINT_URL=http://localstack:4566
      - AWS_ACCESS_KEY_ID=test
      - AWS_SECRET_ACCESS_KEY=test
      - AWS_REGION=us-east-1
      - S3_BUCKET=breiq-videos-local
      - JWT_SECRET=dev_jwt_secret_key_change_in_production
      - UPLOAD_MAX_SIZE=100MB
      - CORS_ORIGINS=http://localhost:3000,http://localhost:5173
    volumes:
      - ./breiq-backend:/app
      - /app/node_modules
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
      localstack:
        condition: service_started
    command: npm run dev

  frontend:
    build:
      context: ./breiq
      dockerfile: Dockerfile.dev
    ports:
      - "3000:3000"
    environment:
      - REACT_APP_API_URL=http://localhost:8000/api
      - REACT_APP_WS_URL=ws://localhost:8000
      - REACT_APP_CDN_URL=http://localhost:4566/breiq-videos-local
      - NODE_ENV=development
    volumes:
      - ./breiq:/app
      - /app/node_modules
    depends_on:
      - backend
    command: npm start

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./scripts/nginx.dev.conf:/etc/nginx/nginx.conf
      - ./scripts/ssl:/etc/nginx/ssl
    depends_on:
      - frontend
      - backend

volumes:
  postgres_data:
  redis_data:
  localstack_data:
EOF

# Create development Nginx configuration
print_status "Creating Nginx development configuration..."

mkdir -p scripts/ssl

cat > scripts/nginx.dev.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream backend {
        server backend:8000;
    }
    
    upstream frontend {
        server frontend:3000;
    }
    
    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name localhost;
        return 301 https://$server_name$request_uri;
    }
    
    server {
        listen 443 ssl;
        server_name localhost;
        
        ssl_certificate /etc/nginx/ssl/localhost.crt;
        ssl_certificate_key /etc/nginx/ssl/localhost.key;
        
        # Frontend
        location / {
            proxy_pass http://frontend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        # Backend API
        location /api/ {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        # WebSocket support
        location /ws {
            proxy_pass http://backend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
EOF

# Generate self-signed SSL certificate for local development
print_status "Generating self-signed SSL certificate for local development..."

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout scripts/ssl/localhost.key \
    -out scripts/ssl/localhost.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=localhost"

# Create development Dockerfiles if they don't exist
print_status "Creating development Dockerfiles..."

if [ ! -f "breiq-backend/Dockerfile.dev" ]; then
    cat > breiq-backend/Dockerfile.dev << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Expose port
EXPOSE 8000

# Start in development mode with hot reload
CMD ["npm", "run", "dev"]
EOF
fi

if [ ! -f "breiq/Dockerfile.dev" ]; then
    cat > breiq/Dockerfile.dev << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Expose port
EXPOSE 3000

# Start in development mode
CMD ["npm", "start"]
EOF
fi

# Create LocalStack initialization script
print_status "Creating LocalStack initialization script..."

cat > scripts/init-localstack.sh << 'EOF'
#!/bin/bash

# Wait for LocalStack to be ready
echo "Waiting for LocalStack to be ready..."
while ! curl -s http://localhost:4566/_localstack/health | grep -q "running"; do
    sleep 2
done

echo "LocalStack is ready! Initializing AWS resources..."

# Create S3 bucket for videos
aws --endpoint-url=http://localhost:4566 s3 mb s3://breiq-videos-local

# Enable S3 bucket for static website hosting
aws --endpoint-url=http://localhost:4566 s3 website s3://breiq-videos-local \
    --index-document index.html --error-document error.html

# Set bucket CORS policy
cat > /tmp/cors-policy.json << 'CORS_EOF'
{
    "CORSRules": [
        {
            "AllowedHeaders": ["*"],
            "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
            "AllowedOrigins": ["http://localhost:3000", "https://localhost"],
            "ExposeHeaders": ["ETag"]
        }
    ]
}
CORS_EOF

aws --endpoint-url=http://localhost:4566 s3api put-bucket-cors \
    --bucket breiq-videos-local \
    --cors-configuration file:///tmp/cors-policy.json

echo "✅ LocalStack resources initialized successfully!"
EOF

chmod +x scripts/init-localstack.sh

# Start the development environment
print_status "Starting development environment..."

# Build and start services
docker-compose -f docker-compose.local.yml down
docker-compose -f docker-compose.local.yml up --build -d

# Wait for services to be ready
print_status "Waiting for services to be ready..."
sleep 30

# Initialize LocalStack resources
print_status "Initializing LocalStack resources..."
./scripts/init-localstack.sh

# Run database migrations
print_status "Running database migrations..."
docker-compose -f docker-compose.local.yml exec backend npm run migrate

# Run database seeds (if available)
if docker-compose -f docker-compose.local.yml exec backend npm run seed:dev 2>/dev/null; then
    print_success "Database seeded with development data"
fi

print_success "🎉 Breiq development environment is ready!"
echo ""
echo "📋 Service URLs:"
echo "   Frontend:     https://localhost"
echo "   Backend API:  http://localhost:8000/api"
echo "   Database:     localhost:5432 (breiq_dev/breiq_user/breiq_pass)"
echo "   Redis:        localhost:6379"
echo "   LocalStack:   http://localhost:4566"
echo ""
echo "🔧 Useful commands:"
echo "   View logs:    docker-compose -f docker-compose.local.yml logs -f"
echo "   Stop:         docker-compose -f docker-compose.local.yml down"
echo "   Restart:      docker-compose -f docker-compose.local.yml restart"
echo ""
echo "⚠️  Note: Accept the self-signed certificate in your browser for HTTPS"
echo ""
print_success "Happy coding! 🚀"