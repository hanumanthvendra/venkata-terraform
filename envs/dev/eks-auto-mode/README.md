# EKS Auto Mode Terraform Configuration

This directory contains Terraform configuration for creating an Amazon EKS cluster with Auto Mode enabled in the `ap-south-1` region.

## Features

- **EKS Auto Mode**: Automatically manages compute resources, storage, and load balancers
- **Remote State Backend**: Uses S3 backend with encryption and DynamoDB locking
- **Network Integration**: References VPC and subnets from network remote state
- **Security**: Configured with appropriate IAM roles and security groups

## Prerequisites

1. **AWS CLI**: Configured with appropriate permissions
2. **Terraform**: Version >= 1.5.7
3. **Network Infrastructure**: Deployed network infrastructure with outputs in S3 backend
4. **Backend Setup**: S3 bucket and DynamoDB table for state management

## Backend Configuration

The backend is configured in `backend.hcl`:
- **Bucket**: `terraform-backend-venkata`
- **Key**: `dev/eks-auto-mode-3/terraform.tfstate`
- **Region**: `ap-south-1`
- **Encryption**: Enabled with KMS key `alias/terraform-backend`
- **Locking**: DynamoDB table `terraform-backend-venkata-locks`

## Network Dependencies

This configuration expects the following outputs from the network remote state:
- `vpc_id`: The VPC ID where the EKS cluster will be created
- `private_subnet_ids`: List of private subnet IDs for EKS nodes

## Usage

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Review the Plan

```bash
terraform plan
```

### 3. Deploy the Infrastructure

```bash
terraform apply
```

### 4. Configure kubectl

After deployment, configure kubectl to connect to your cluster:

```bash
aws eks update-kubeconfig --name $(terraform output -raw cluster_name) --region ap-south-1
```

## Configuration Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `cluster_name` | Name of the EKS cluster | `eks-auto-mode-cluster` | No |
| `kubernetes_version` | Kubernetes version | `1.33` | No |
| `environment` | Environment name | `dev` | No |
| `region` | AWS region | `ap-south-1` | No |
| `enable_public_access` | Enable public access to EKS endpoint | `true` | No |
| `node_pools` | List of node pools for Auto Mode | `["general-purpose"]` | No |
| `tags` | Additional resource tags | `{}` | No |

## Outputs

The following outputs are available after deployment:

- `cluster_endpoint`: EKS cluster API endpoint
- `cluster_certificate_authority_data`: Certificate data for cluster authentication
- `cluster_name`: Name of the created cluster
- `cluster_oidc_issuer_url`: OIDC provider URL for IRSA
- `node_iam_role_arn`: IAM role ARN for EKS Auto nodes
- `cluster_security_group_id`: Security group ID for the cluster

## ALB/Ingress Configuration

This configuration includes the AWS Load Balancer Controller for handling ingress resources and ALB creation:

### Features
- **AWS Load Balancer Controller**: Manages ALBs for ingress resources
- **IAM Role**: Dedicated IAM role with required permissions
- **Helm Installation**: Automated installation via Terraform null_resource
- **IngressClass**: Default ingress class configured for ALB
- **SSL/TLS Support**: Ready for certificate management

### Installation Process
The ALB controller is automatically installed after cluster creation using:
1. **IAM Role Creation**: Creates dedicated IAM role for ALB controller
2. **Policy Attachment**: Attaches AWSLoadBalancerControllerIAMPolicy
3. **Helm Installation**: Installs controller via Helm with proper configuration
4. **Service Account**: Configured with IRSA for secure AWS API access

### Testing ALB Functionality

#### 1. Deploy ALB Test Application

```bash
# Deploy the test application with ALB configuration
kubectl apply -f alb-test.yaml
```

#### 2. Verify ALB Creation

```bash
# Check if ALB is created
kubectl get ingress

# Check load balancer service
kubectl get svc -l app=nginx-alb-test

# Check AWS load balancers
aws elbv2 describe-load-balancers --region ap-south-1 --query 'LoadBalancers[?contains(LoadBalancerName, `nginx-alb-test`)]'
```

#### 3. Test Application Access

```bash
# Get the ALB DNS name
ALB_DNS=$(kubectl get ingress nginx-alb-test -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test the application
curl http://$ALB_DNS

# Or access via browser
echo "Open in browser: http://$ALB_DNS"
```

### Alternative: LoadBalancer Service

For simpler load balancing without ingress:

```bash
# Create a service with LoadBalancer type
kubectl expose deployment nginx-alb-test --type=LoadBalancer --port=80 --target-port=80 --name=nginx-lb

# Check the load balancer
kubectl get svc nginx-lb
```

## Testing the Deployment

### 1. Deploy a Test Application

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: test
  template:
    metadata:
      labels:
        app: test
    spec:
      containers:
      - name: test
        image: nginx:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
EOF
```

### 2. Verify Auto Mode Scaling

```bash
# Check nodes created by Auto Mode
kubectl get nodes

# Check node pools
kubectl get nodepools

# Check pod status
kubectl get pods -o wide
```

## Security Considerations

1. **IAM Permissions**: Ensure appropriate IAM permissions for EKS Auto Mode
2. **Network Security**: Review security group rules and network policies
3. **Encryption**: KMS encryption is enabled for the backend and EBS volumes
4. **Access Control**: Use IRSA for pod-level permissions

## Cost Optimization

- EKS Auto Mode automatically scales nodes based on workload requirements
- Monitor resource utilization to optimize node pool configurations
- Consider using spot instances for non-critical workloads

## Troubleshooting

### Common Issues

1. **Network Connectivity**: Verify VPC and subnet configurations in the remote state
2. **IAM Permissions**: Check IAM roles and policies for required permissions
3. **Resource Limits**: Ensure AWS account limits are sufficient for EKS resources

### Useful Commands

```bash
# Check cluster status
kubectl get nodes
kubectl get nodepools

# Check EKS cluster details
aws eks describe-cluster --name $(terraform output -raw cluster_name) --region ap-south-1

# Check IAM roles
aws iam get-role --role-name $(terraform output -raw node_iam_role_name)

# View logs
kubectl logs -f <pod-name>
```

## Cleanup

To destroy the infrastructure:

```bash
terraform destroy
```

**Note**: This will destroy the EKS cluster and all associated resources. Ensure you have backed up any important data before running this command.
