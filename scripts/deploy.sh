#!/bin/bash

# Universal Foundation - Production Deployment Script
# This script deploys the complete ECS Fargate infrastructure

set -e

# Configuration
PROJECT_NAME="universal-foundation"
TENANT_ID="PROD"
ENVIRONMENT="production"
REGION="us-east-1"

# User configurable variables
DOMAIN_NAME="${DOMAIN_NAME:-}"
ALERT_EMAIL="${ALERT_EMAIL:-}"
MANAGE_DNS="${MANAGE_DNS:-true}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured. Run 'aws configure' first."
        exit 1
    fi
    
    log_success "All prerequisites met"
}

# Get user configuration
get_user_config() {
    log_info "Getting deployment configuration..."
    
    if [ -z "$DOMAIN_NAME" ]; then
        read -p "Enter your domain name (e.g., api.yourdomain.com) or press Enter to skip: " DOMAIN_NAME
    fi
    
    if [ -z "$ALERT_EMAIL" ]; then
        read -p "Enter email for alerts (or press Enter to skip): " ALERT_EMAIL
    fi
    
    # Display configuration
    echo ""
    log_info "Deployment Configuration:"
    echo "  Project: $PROJECT_NAME"
    echo "  Tenant: $TENANT_ID"
    echo "  Environment: $ENVIRONMENT"
    echo "  Region: $REGION"
    echo "  Domain: ${DOMAIN_NAME:-"none (will use ALB DNS)"}"
    echo "  Alert Email: ${ALERT_EMAIL:-"none"}"
    echo ""
    
    read -p "Proceed with this configuration? (y/N): " confirm
    if [[ $confirm != [yY] ]]; then
        log_warning "Deployment cancelled"
        exit 0
    fi
}

# Deploy infrastructure
deploy_infrastructure() {
    log_info "Deploying infrastructure with Terraform..."
    
    cd infra/terraform
    
    # Initialize Terraform
    terraform init
    
    # Create terraform.tfvars
    cat > terraform.tfvars << EOF
project_name = "$PROJECT_NAME"
tenant_id = "$TENANT_ID"
environment = "$ENVIRONMENT"
region = "$REGION"
domain_name = "$DOMAIN_NAME"
alert_email = "$ALERT_EMAIL"
manage_dns = $MANAGE_DNS
enable_waf = true
enable_cloudtrail = true
create_artifacts_bucket = true
EOF
    
    # Plan deployment
    log_info "Creating deployment plan..."
    terraform plan -out=tfplan
    
    # Apply deployment
    log_info "Applying infrastructure changes..."
    terraform apply tfplan
    
    # Get outputs
    log_info "Getting infrastructure outputs..."
    ECR_REPO=$(terraform output -raw ecr_sign_service_repository_url 2>/dev/null || echo "")
    ECS_CLUSTER=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "")
    API_ENDPOINT=$(terraform output -raw api_endpoint 2>/dev/null || echo "")
    
    cd ../..
    
    log_success "Infrastructure deployed successfully"
    
    if [ ! -z "$ECR_REPO" ]; then
        export ECR_REPOSITORY_URL="$ECR_REPO"
        export ECS_CLUSTER_NAME="$ECS_CLUSTER"
        export API_ENDPOINT_URL="$API_ENDPOINT"
    fi
}

# Build and push container
build_and_push_container() {
    if [ -z "$ECR_REPOSITORY_URL" ]; then
        log_warning "ECR repository not available, skipping container build"
        return
    fi
    
    log_info "Building and pushing container image..."
    
    cd services/sign-service
    
    # Build the application
    log_info "Building TypeScript application..."
    npm run build
    
    # Build Docker image
    log_info "Building Docker image..."
    docker build -t $PROJECT_NAME-$TENANT_ID-sign-service .
    
    # Tag for ECR
    docker tag $PROJECT_NAME-$TENANT_ID-sign-service:latest $ECR_REPOSITORY_URL:latest
    docker tag $PROJECT_NAME-$TENANT_ID-sign-service:latest $ECR_REPOSITORY_URL:$(date +%Y%m%d-%H%M%S)
    
    # Login to ECR
    log_info "Logging into ECR..."
    aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REPOSITORY_URL
    
    # Push images
    log_info "Pushing images to ECR..."
    docker push $ECR_REPOSITORY_URL:latest
    docker push $ECR_REPOSITORY_URL:$(date +%Y%m%d-%H%M%S)
    
    cd ../..
    
    log_success "Container image built and pushed successfully"
}

# Update ECS service
update_ecs_service() {
    if [ -z "$ECS_CLUSTER_NAME" ]; then
        log_warning "ECS cluster not available, skipping service update"
        return
    fi
    
    log_info "Updating ECS service..."
    
    # Force new deployment
    aws ecs update-service \
        --cluster $ECS_CLUSTER_NAME \
        --service $PROJECT_NAME-$TENANT_ID-sign-service \
        --force-new-deployment \
        --region $REGION
    
    # Wait for deployment to complete
    log_info "Waiting for deployment to complete..."
    aws ecs wait services-stable \
        --cluster $ECS_CLUSTER_NAME \
        --services $PROJECT_NAME-$TENANT_ID-sign-service \
        --region $REGION
    
    log_success "ECS service updated successfully"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment..."
    
    if [ ! -z "$API_ENDPOINT_URL" ]; then
        log_info "Testing API endpoint: $API_ENDPOINT_URL"
        
        # Wait a bit for load balancer to be ready
        sleep 30
        
        # Test health endpoint
        if curl -f -s "$API_ENDPOINT_URL/v1/health" > /dev/null; then
            log_success "API health check passed"
        else
            log_warning "API health check failed - this is normal for new deployments"
            log_info "The service may take 5-10 minutes to be fully ready"
        fi
    fi
    
    # Display important information
    echo ""
    log_success "Deployment completed!"
    echo ""
    echo "Important Information:"
    echo "===================="
    
    if [ ! -z "$API_ENDPOINT_URL" ]; then
        echo "API Endpoint: $API_ENDPOINT_URL"
        echo "Health Check: $API_ENDPOINT_URL/v1/health"
        echo "Admin Stats: $API_ENDPOINT_URL/v1/admin/stats"
    fi
    
    if [ ! -z "$ECS_CLUSTER_NAME" ]; then
        echo "ECS Cluster: $ECS_CLUSTER_NAME"
    fi
    
    echo ""
    echo "Next Steps:"
    echo "==========="
    echo "1. Wait 5-10 minutes for all services to be fully ready"
    echo "2. Test the API endpoints"
    echo "3. Monitor CloudWatch dashboard for metrics"
    
    if [ ! -z "$DOMAIN_NAME" ] && [ "$MANAGE_DNS" = "true" ]; then
        echo "4. Update your domain's nameservers to point to Route 53"
        cd infra/terraform
        terraform output nameservers
        cd ../..
    fi
}

# Main execution
main() {
    echo ""
    log_info "Universal Foundation - Production Deployment"
    echo "============================================="
    echo ""
    
    case "${1:-all}" in
        "check")
            check_prerequisites
            ;;
        "infra")
            check_prerequisites
            get_user_config
            deploy_infrastructure
            ;;
        "build")
            build_and_push_container
            ;;
        "service")
            update_ecs_service
            ;;
        "verify")
            verify_deployment
            ;;
        "all")
            check_prerequisites
            get_user_config
            deploy_infrastructure
            build_and_push_container
            update_ecs_service
            verify_deployment
            ;;
        *)
            echo "Usage: $0 [check|infra|build|service|verify|all]"
            echo ""
            echo "Commands:"
            echo "  check   - Check prerequisites only"
            echo "  infra   - Deploy infrastructure only"
            echo "  build   - Build and push container only"
            echo "  service - Update ECS service only"
            echo "  verify  - Verify deployment only"
            echo "  all     - Run complete deployment (default)"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
