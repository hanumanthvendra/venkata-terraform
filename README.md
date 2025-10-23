# venkata-terraform

## Overview

This repository contains a comprehensive Terraform-based infrastructure-as-code (IaC) project designed for end-to-end provisioning and management of cloud infrastructure on AWS. It demonstrates the creation of a complete cloud-native environment, including networking, compute, serverless functions, container orchestration, CI/CD pipelines, and monitoring. The project integrates multiple tools and services to provide a production-ready setup for deploying applications, with a focus on scalability, security, and automation.

Key features include:
- **Infrastructure Provisioning**: VPC, subnets, security groups, and other foundational AWS resources.
- **Compute and Orchestration**: Amazon EKS (Elastic Kubernetes Service) clusters, including both standard managed node groups and the newer EKS Auto Mode for simplified node management.
- **Serverless Components**: AWS Lambda functions, API Gateway, and CloudFront distributions for edge computing and content delivery.
- **Application Deployment**: Sample Flask application (Flamecraft) with Helm charts for Kubernetes deployment, including Horizontal Pod Autoscaling (HPA).
- **CI/CD Integration**: Jenkins setup for automated pipelines, including testing and deployment jobs.
- **Monitoring and Observability**: Prometheus, Grafana, and custom metrics for application and infrastructure monitoring.
- **Add-ons and Extensions**: EKS add-ons like ALB Controller, EBS CSI Driver, Secrets CSI Driver, and Pod Identity for enhanced functionality.
- **Testing and Playground**: Environments for testing add-ons, load generation, and experimental features.

This project serves as a reference for building scalable, multi-environment AWS infrastructures using Terraform modules, with real-world examples of integrating Kubernetes, serverless, and DevOps tools.

## Directory Structure

```
venkata-terraform/
├── .gitignore                    # Git ignore rules for Terraform state and sensitive files
├── README.md                     # This file - project overview and documentation
├── terraform.tfstate             # Terraform state file (generated)
├── .git/                         # Git repository metadata
├── envs/                         # Environment-specific configurations
│   └── dev/                      # Development environment
│       ├── .terraform/           # Terraform cache and plugins
│       ├── backend/              # Remote backend configuration (e.g., S3)
│       ├── eks/                  # Standard EKS cluster configuration
│       ├── eks-auto-mode/        # EKS Auto Mode cluster configuration
│       ├── lambda/               # Lambda function environment setup
│       └── network/              # VPC and networking resources
├── flamecraft-app/               # Sample Flask application
│   ├── app.py                    # Main Flask application code
│   ├── Dockerfile                # Docker image for the app
│   ├── Dockerfile.test           # Docker image for testing
│   ├── flamecraft-hpa.yaml       # HPA configuration for scaling
│   ├── flamecraft.yaml           # Kubernetes deployment manifest
│   ├── gunicorn.conf.py          # Gunicorn configuration
│   ├── Jenkinsfile               # Jenkins pipeline for CI/CD
│   ├── README-full-pipeline.md   # Documentation for full pipeline
│   ├── README-testing.md         # Testing documentation
│   ├── regression-test-job.yaml  # Kubernetes job for regression tests
│   ├── requirements.txt          # Python dependencies
│   ├── simple_test.py            # Simple test script
│   ├── test_regression.py        # Regression test script
│   ├── test-job.yaml             # Kubernetes test job
│   └── helm/                     # Helm chart for app deployment
│       ├── Chart.yaml            # Helm chart metadata
│       ├── templates/            # Helm templates
│       │   ├── _helpers.tpl      # Helper templates
│       │   ├── deployment.yaml   # Deployment template
│       │   ├── hpa.yaml          # HPA template
│       │   ├── NOTES.txt         # Post-install notes
│       │   └── service.yaml      # Service template
│       ├── values.yaml           # Default values for Helm chart
│       └── README.md             # Helm chart documentation
├── jenkins/                      # Jenkins CI/CD setup
│   ├── README.md                 # Jenkins configuration documentation
│   ├── ui-only.yaml              # UI-only Jenkins deployment
│   └── values.yaml               # Helm values for Jenkins
├── modules/                      # Reusable Terraform modules
│   ├── api-gateway/              # API Gateway module
│   ├── cloudfront/               # CloudFront distribution module
│   ├── eks/                      # Standard EKS module
│   ├── eks-addons/               # EKS add-ons (ALB, EBS CSI, Secrets CSI, etc.)
│   ├── eks-auto-mode/            # EKS Auto Mode module
│   ├── lambda/                   # Lambda function module
│   ├── s3-backend/               # S3 backend for Terraform state
│   └── vpc/                      # VPC and networking module
├── monitoring-configs/           # Monitoring and observability configurations
│   ├── adapter.yaml              # Prometheus adapter config
│   ├── config.yaml               # General config
│   ├── custom-metric-rule.yaml   # Custom metrics rules
│   ├── HPA-Configuration-README.md # HPA setup guide
│   ├── load-generator-heavy.yaml # Load generator for testing
│   ├── metrics-server.yaml       # Metrics server deployment
│   ├── metrics-values.yaml       # Metrics values
│   ├── monitoring-ingress.yaml   # Ingress for monitoring tools
│   ├── Prometheus-Flamecraft-HPA-Medium-Doc.md # Documentation
│   ├── README-HPA-EKS-Auto-Scaling.md # HPA guide
│   ├── servicemonitor-flamecraft.yaml # Service monitor for app
│   └── values-prom-adapter.yaml  # Prometheus adapter values
└── playgroud/                    # Experimental and testing area
    ├── deployment.yaml           # Sample deployments
    ├── EKS-Auto-Mode-Creation-Guide.md # Guide for EKS Auto Mode
    ├── generate-scaling-demo.sh  # Script for scaling demos
    ├── HPA-EKS-Auto-Mode-Presentation.md # Presentation on HPA
    ├── hpa.yaml                  # HPA config
    ├── medium-blog-secrets-csi-driver.md # Blog/documentation
    └── TODO.md                   # Playground tasks
```

## Key Components

### Infrastructure Modules
- **VPC**: Creates virtual private clouds with subnets, internet gateways, and NAT gateways.
- **EKS**: Provisions Kubernetes clusters with managed node groups or auto-mode.
- **EKS Add-ons**: Includes controllers for load balancing (ALB), storage (EBS CSI), secrets management (Secrets CSI), and identity (Pod Identity).
- **Serverless**: Lambda functions with API Gateway and CloudFront for global distribution.

### Application Layer
- **Flamecraft App**: A sample Python Flask application demonstrating containerization, Helm deployment, and autoscaling on Kubernetes.
- **Helm Charts**: Templated deployments for easy application management.

### CI/CD and Automation
- **Jenkins**: Automated pipelines for building, testing, and deploying applications.
- **Testing**: Includes unit tests, regression tests, and Kubernetes job-based testing.

### Monitoring and Scaling
- **Prometheus & Grafana**: For metrics collection, visualization, and alerting.
- **HPA**: Horizontal Pod Autoscaling based on custom metrics.
- **Load Generators**: Tools for simulating traffic to test scaling.

### Environments
- **dev**: Development environment with all components configured for testing and experimentation.

## Getting Started

1. **Prerequisites**:
   - AWS CLI configured with appropriate permissions.
   - Terraform (>= 1.0).
   - kubectl for Kubernetes interactions.
   - Helm for application deployments.
   - Docker for building images.

2. **Clone the Repository**:
   ```bash
   git clone <repository-url>
   cd venkata-terraform
   ```

3. **Initialize Terraform**:
   Navigate to an environment directory (e.g., `envs/dev/eks-auto-mode/`):
   ```bash
   terraform init
   ```

4. **Plan and Apply**:
   ```bash
   terraform plan
   terraform apply
   ```

5. **Deploy Applications**:
   Use Helm to deploy the Flamecraft app:
   ```bash
   helm install flamecraft ./flamecraft-app/helm
   ```

6. **Access Monitoring**:
   Port-forward Grafana or Prometheus services to view dashboards.

For detailed guides, refer to the README files in specific directories (e.g., `envs/dev/eks-auto-mode/README.md` for EKS setup).

## Contributing

- Follow Terraform best practices for module development.
- Use descriptive commit messages.
- Test changes in the `dev` environment before proposing merges.

## License

This project is licensed under the MIT License. See LICENSE file for details.
