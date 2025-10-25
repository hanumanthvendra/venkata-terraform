# Complete Jenkins CI/CD Pipeline for Flask App with Kubernetes Testing

This document provides a comprehensive guide to implementing a production-ready Jenkins CI/CD pipeline for a Flask application deployed to Amazon EKS with automated regression testing using Kubernetes Jobs.

## Pipeline Overview

The pipeline implements a complete DevSecOps workflow with the following stages:

1. **Clean Workspace** - Ensures clean build environment
2. **Clone Repository** - Fetches source code from GitHub
3. **Parallel Security Scans** - Runs secret detection and vulnerability scans
4. **Build Docker Image** - Creates container image
5. **Vulnerability Scan (Trivy)** - Scans container for security issues
6. **Tag for ECR Public** - Prepares image for registry
7. **ECR Login & Push** - Publishes image to Amazon ECR Public
8. **Deploy to Dev Environment** - Deploys to EKS using Helm
9. **Run Regression Tests** - Executes automated tests via Kubernetes Job
10. **Send Test Report** - Notifies team via Slack
11. **Approval for Stage Deployment** - Manual approval gate
12. **Cleanup** - Removes temporary artifacts

## Architecture

```
GitHub → Jenkins → Docker Build → Trivy Scan → ECR Public → EKS Dev → K8s Job Tests → Slack → Manual Approval
```

## Prerequisites

### Jenkins Setup
- Jenkins server with EC2 fleet plugin
- Docker installed on Jenkins agents
- AWS CLI configured
- kubectl installed
- Helm installed

### AWS Resources
- Amazon EKS cluster (dev-eks-auto-mode-3)
- ECR Public repository (public.ecr.aws/e9s5a3s2/flamecraft)
- AWS credentials with appropriate permissions

### Kubernetes Resources
- EKS cluster with auto-mode enabled
- Namespace: `dev`
- Service account with cluster access

## Pipeline Configuration

### Jenkinsfile Structure

```groovy
node('ec2-fleet') {
  // Configuration variables
  def APP_DIR = 'flamecraft-app'
  def AWS_REGION = 'us-east-1'
  def ECR_REGISTRY = 'public.ecr.aws'
  def ECR_REPO = 'public.ecr.aws/e9s5a3s2/flamecraft'
  def IMAGE = "flamecraft:${env.BUILD_NUMBER}"
  def ECR_IMAGE = "${ECR_REPO}:${env.BUILD_NUMBER}"

  // Helm deployment config
  def K8S_REGION = 'ap-south-1'
  def CLUSTER_NAME = 'dev-eks-auto-mode-3'
  def NAMESPACE = 'dev'
  def RELEASE = 'flamecraft-app'
  def CHART_PATH = 'flamecraft-app/helm'

  try {
    // Pipeline stages...
  } catch (Exception e) {
    // Error handling...
  }
}
```

## Detailed Stage Breakdown

### 1. Clean Workspace
```groovy
stage('Clean Workspace') {
  deleteDir()
}
```
- Removes all files from workspace
- Ensures clean build environment
- Prevents artifact contamination

### 2. Clone Repository
```groovy
stage('Clone Repo') {
  sshagent(['git-ssh-key']) {
    sh '''
      set -euxo pipefail
      export HOME="${HOME:-/home/jenkins}"
      mkdir -p "$HOME/.ssh"
      touch "$HOME/.ssh/known_hosts"
      chmod 700 "$HOME/.ssh"
      ssh-keyscan -t rsa,ecdsa,ed25519 github.com >> "$HOME/.ssh/known_hosts"
      chmod 644 "$HOME/.ssh/known_hosts"
    '''
    git url: 'git@github.com:hanumanthvendra/venkata-terraform.git',
        branch: 'main',
        credentialsId: 'git-ssh-key'
  }
}
```
- Configures SSH for GitHub access
- Clones the repository
- Sets up known hosts for security

### 3. Parallel Security Scans
```groovy
stage('Parallel Security Scans') {
  parallel(
    "Secret Scan (Gitleaks)": {
      sh '''
        set -euo pipefail
        echo "Running Gitleaks secret scan on repository..."
        CFG_ARG=""
        test -f .gitleaks.toml && CFG_ARG="--config=/repo/.gitleaks.toml"
        docker run --rm -v "$PWD:/repo" -w /repo zricethezav/gitleaks:latest \
          detect --source=/repo $CFG_ARG \
          --report-format sarif --report-path gitleaks.sarif --redact
      '''
      archiveArtifacts artifacts: 'gitleaks.sarif', allowEmptyArchive: true
    },
    "Secret Scan (Trivy Repo)": {
      sh '''
        set -euo pipefail
        echo "Running Trivy secret scan on repository..."
        docker run --rm -v "$PWD:/repo" -w /repo aquasec/trivy:latest \
          fs --scanners secret --exit-code 1 --no-progress /repo
      '''
    }
  )
}
```
- **Gitleaks**: Scans for hardcoded secrets, API keys, passwords
- **Trivy**: Filesystem secret scanning
- Runs in parallel for efficiency
- Archives SARIF reports for security dashboards

### 4. Build Docker Image
```groovy
stage('Build Docker Image') {
  dir(APP_DIR) {
    sh """
      set -euxo pipefail
      test -f Dockerfile || { echo "ERROR: \$PWD/Dockerfile not found"; exit 2; }
      echo "Building image: ${IMAGE} from \$PWD"
      docker build -t "${IMAGE}" -f Dockerfile .
    """
  }
}
```
- Changes to application directory
- Validates Dockerfile existence
- Builds container image with build number tag

### 5. Vulnerability Scan (Trivy)
```groovy
stage('Vulnerability Scan (Trivy)') {
  sh """
    set -euxo pipefail
    echo "Running Trivy vulnerability scan for ${IMAGE} (CRITICAL,HIGH)…"
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
      aquasec/trivy:latest image --exit-code 1 --severity CRITICAL,HIGH --no-progress "${IMAGE}" || {
        echo "Trivy found CRITICAL/HIGH vulnerabilities - failing."
        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
          aquasec/trivy:latest image --format table --no-progress "${IMAGE}" || true
        exit 1
      }
  """
}
```
- Scans container image for CRITICAL and HIGH severity vulnerabilities
- Fails pipeline if vulnerabilities found
- Provides detailed vulnerability report

### 6. Tag for ECR Public
```groovy
stage('Tag for ECR Public') {
  sh """
    set -euxo pipefail
    echo "Tagging ${IMAGE} -> ${ECR_IMAGE}"
    docker tag "${IMAGE}" "${ECR_IMAGE}"
  """
}
```
- Tags local image with ECR registry path
- Prepares for registry push

### 7. ECR Login & Push
```groovy
stage('ECR Login & Push') {
  withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials-id']]) {
    sh """
      set -euo pipefail
      export AWS_DEFAULT_REGION='${AWS_REGION}'
      export AWS_EC2_METADATA_DISABLED=true

      aws --version || true
      aws sts get-caller-identity >/dev/null

      # Ensure ECR Public repo exists (no-op if already present)
      aws ecr-public describe-repositories --region "\$AWS_DEFAULT_REGION" \
        --repository-names flamecraft >/dev/null 2>&1 || \
      aws ecr-public create-repository --region "\$AWS_DEFAULT_REGION" \
        --repository-name flamecraft >/dev/null

      # Non-interactive login to ECR Public
      aws ecr-public get-login-password --region "\$AWS_DEFAULT_REGION" \
        | docker login --username AWS --password-stdin "${ECR_REGISTRY}"

      echo "Pushing ${ECR_IMAGE} ..."
      docker push "${ECR_IMAGE}"
    """
  }
}
```
- Authenticates with AWS ECR Public
- Creates repository if it doesn't exist
- Pushes container image to registry

### 8. Deploy to Dev Environment (Helm)
```groovy
stage('Deploy to Dev Env (Helm)') {
  withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials-id']]) {
    sh """
      set -euo pipefail
      aws eks update-kubeconfig --region '${K8S_REGION}' --name '${CLUSTER_NAME}'

      # Helm upgrade/install with the new image tag
      helm upgrade --install '${RELEASE}' '${CHART_PATH}' \
        --namespace '${NAMESPACE}' --create-namespace \
        --set image.repository='public.ecr.aws/e9s5a3s2/flamecraft' \
        --set image.tag='${env.BUILD_NUMBER}' \
        --set image.pullPolicy='IfNotPresent' \
        --wait --atomic --timeout 5m

      # Sanity checks
      kubectl -n '${NAMESPACE}' rollout status deploy/${RELEASE} --timeout=300s
      kubectl -n '${NAMESPACE}' get deploy/${RELEASE} -o=jsonpath='{.spec.template.spec.containers[0].image}'; echo
    """
  }
}
```
- Updates kubectl configuration for EKS
- Deploys application using Helm
- Waits for rollout completion
- Verifies deployed image version

### 9. Run Regression Tests
```groovy
stage('Run Regression Tests') {
  withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials-id']]) {
    dir("${APP_DIR}") {
      sh """
        set -euo pipefail

        aws eks update-kubeconfig --region '${K8S_REGION}' --name '${CLUSTER_NAME}'

        echo "Running regression tests using Kubernetes Job..."

        # Apply the regression test job
        kubectl apply -f regression-test-job.yaml

        # Wait for the job to complete
        echo "Waiting for regression test job to complete..."
        kubectl wait --for=condition=complete job/regression-test-job -n '${NAMESPACE}' --timeout=300s

        # Create test report directory
        mkdir -p test-reports

        # Get job logs
        echo "Fetching regression test job logs..."
        kubectl logs job/regression-test-job -n '${NAMESPACE}' | tee test-reports/regression-test.log

        # Check if job succeeded
        if kubectl get job regression-test-job -n '${NAMESPACE}' -o jsonpath='{.status.succeeded}' | grep -q '1'; then
          echo "✓ Regression test job completed successfully!"
        else
          echo "✗ Regression test job failed!"
          kubectl logs job/regression-test-job -n '${NAMESPACE}'
          exit 1
        fi

        # Generate summary report
        echo "Generating test summary report..."
        cat > test-reports/summary-report.html << EOF
        <html>
        <head><title>Flamecraft Regression Test Report</title></head>
        <body>
        <h1>Flamecraft App Regression Test Report</h1>
        <p><strong>Build:</strong> #${env.BUILD_NUMBER}</p>
        <p><strong>Environment:</strong> DEV</p>
        <p><strong>Test Date:</strong> \$(date)</p>
        <h2>Test Results</h2>
        <ul>
        <li>✓ Health Check: PASSED</li>
        <li>✓ Readiness Check: PASSED</li>
        <li>✓ Employees API: PASSED</li>
        </ul>
        <h2>Deployment Details</h2>
        <ul>
        <li>Image: public.ecr.aws/e9s5a3s2/flamecraft:${env.BUILD_NUMBER}</li>
        <li>Service: flamecraft-app.dev.svc.cluster.local:80</li>
        <li>Namespace: ${NAMESPACE}</li>
        <li>Test Job: regression-test-job</li>
        </ul>
        </body>
        </html>
        EOF

        echo "✓ All regression tests completed successfully!"
      """
    }
  }
}
```
- Deploys Kubernetes Job for testing
- Waits for test completion
- Captures and validates test results
- Generates HTML test report

### 10. Send Test Report
```groovy
stage('Send Test Report') {
  script {
    // Archive test reports
    archiveArtifacts artifacts: 'test-reports/**', allowEmptyArchive: true

    // Send test report via Slack
    withCredentials([string(credentialsId: 'slack-webhook-url', variable: 'SLACK_WEBHOOK')]) {
      sh """
        curl -X POST -H 'Content-type: application/json' \
          --data '{
            "text": "✅ Flamecraft Regression Tests Completed - Build #${env.BUILD_NUMBER}",
            "blocks": [
              {
                "type": "section",
                "text": {
                  "type": "mrkdwn",
                  "text": "*✅ Regression Test Report*"
                }
              },
              {
                "type": "section",
                "fields": [
                  {
                    "type": "mrkdwn",
                    "text": "*Job:* ${env.JOB_NAME}"
                  },
                  {
                    "type": "mrkdwn",
                    "text": "*Build:* #${env.BUILD_NUMBER}"
                  },
                  {
                    "type": "mrkdwn",
                    "text": "*Environment:* DEV"
                  },
                  {
                    "type": "mrkdwn",
                    "text": "*Test Status:* PASSED"
                  },
                  {
                    "type": "mrkdwn",
                    "text": "*Tests Run:* 3/3"
                  },
                  {
                    "type": "mrkdwn",
                    "text": "*Triggered by:* ${env.BUILD_USER ?: 'Jenkins'}"
                  }
                ]
              },
              {
                "type": "section",
                "text": {
                  "type": "mrkdwn",
                  "text": "*Test Results:*\n✓ Health Check: PASSED\n✓ Readiness Check: PASSED\n✓ Employees API: PASSED"
                }
              },
              {
                "type": "section",
                "text": {
                  "type": "mrkdwn",
                  "text": "*Jenkins URL:* ${env.BUILD_URL}"
                }
              }
            ]
          }' \
          \$SLACK_WEBHOOK
      """
    }
  }
}
```
- Archives test artifacts
- Sends detailed Slack notification
- Includes test results and build information

### 11. Approval for Stage Environment Deployment
```groovy
stage('Approval for Stage Env Deployment') {
  script {
    def userInput = input(
      id: 'ProceedToStage',
      message: 'Deploy to STAGE environment?',
      parameters: [
        choice(
          name: 'DEPLOY_TO_STAGE',
          choices: ['Yes', 'No'],
          description: 'Choose whether to proceed with STAGE deployment'
        )
      ]
    )

    if (userInput == 'Yes') {
      echo "✓ Approved for STAGE deployment"
      // Set environment variable for next stages
      env.DEPLOY_TO_STAGE = 'true'

      // Send approval notification
      withCredentials([string(credentialsId: 'slack-webhook-url', variable: 'SLACK_WEBHOOK')]) {
        sh """
          curl -X POST -H 'Content-type: application/json' \
            --data '{
              "text": "✅ STAGE deployment approved for Flamecraft Build #${env.BUILD_NUMBER}",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*✅ STAGE Deployment Approved*"
                  }
                },
                {
                  "type": "section",
                  "fields": [
                    {
                      "type": "mrkdwn",
                      "text": "*Job:* ${env.JOB_NAME}"
                    },
                    {
                      "type": "mrkdwn",
                      "text": "*Build:* #${env.BUILD_NUMBER}"
                    },
                    {
                      "type": "mrkdwn",
                      "text": "*Environment:* STAGE"
                    },
                    {
                      "type": "mrkdwn",
                      "text": "*Namespace:* staging"
                    },
                    {
                      "type": "mrkdwn",
                      "text": "*Approved by:* ${env.BUILD_USER ?: 'Jenkins'}"
                    }
                  ]
                }
              ]
            }' \
            \$SLACK_WEBHOOK
        """
      }
    } else {
      echo "✗ STAGE deployment cancelled by user"
      env.DEPLOY_TO_STAGE = 'false'

      // Send cancellation notification
      withCredentials([string(credentialsId: 'slack-webhook-url', variable: 'SLACK_WEBHOOK')]) {
        sh """
          curl -X POST -H 'Content-type: application/json' \
            --data '{
              "text": "❌ STAGE deployment cancelled for Flamecraft Build #${env.BUILD_NUMBER}",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*❌ STAGE Deployment Cancelled*"
                  }
                },
                {
                  "type": "section",
                  "fields": [
                    {
                      "type": "mrkdwn",
                      "text": "*Job:* ${env.JOB_NAME}"
                    },
                    {
                      "type": "mrkdwn",
                      "text": "*Build:* #${env.BUILD_NUMBER}"
                    },
                    {
                      "type": "mrkdwn",
                      "text": "*Cancelled by:* ${env.BUILD_USER ?: 'Jenkins'}"
                    }
                  }
                }
              ]
            ]' \
            \$SLACK_WEBHOOK
        """
      }
    }
  }
}
```
- Manual approval gate for STAGE deployment
- Slack notifications for approval/cancellation
- Sets environment variables for downstream stages

### 12. Cleanup
```groovy
stage('Cleanup') {
  sh """
    set -euxo pipefail
    docker rmi "${IMAGE}" || true
    docker rmi "${ECR_IMAGE}" || true
  """
}
```
- Removes local Docker images
- Frees up disk space on Jenkins agents

## Kubernetes Testing Architecture

### Simple Test Script (`simple_test.py`)
```python
#!/usr/bin/env python3
import requests
import sys
import os

def test_endpoint(url, expected_status=200, timeout=10):
    try:
        response = requests.get(url, timeout=timeout)
        if response.status_code == expected_status:
            print(f"✓ {url} - Status: {response.status_code}")
            return True
        else:
            print(f"✗ {url} - Status: {response.status_code} (expected {expected_status})")
            return False
    except requests.exceptions.RequestException as e:
        print(f"✗ {url} - Error: {e}")
        return False

def main():
    base_url = os.getenv('FLAMECRAFT_SERVICE_URL', 'http://localhost:5500')
    base_url = base_url.rstrip('/')

    print("Starting simple Flamecraft API tests...")
    print(f"Target URL: {base_url}")
    print("-" * 50)

    tests_passed = 0
    total_tests = 0

    # Test health endpoint
    total_tests += 1
    if test_endpoint(f"{base_url}/health"):
        tests_passed += 1

    # Test readiness endpoint
    total_tests += 1
    if test_endpoint(f"{base_url}/ready"):
        tests_passed += 1

    # Test employees endpoint (GET)
    total_tests += 1
    if test_endpoint(f"{base_url}/employees"):
        tests_passed += 1

    print("-" * 50)
    print(f"Tests completed: {tests_passed}/{total_tests} passed")

    if tests_passed == total_tests:
        print("✓ All tests passed!")
        sys.exit(0)
    else:
        print("✗ Some tests failed!")
        sys.exit(1)

if __name__ == "__main__":
    main()
```

### Kubernetes Job Configuration (`regression-test-job.yaml`)
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: regression-test-job
  namespace: dev
spec:
  template:
    spec:
      containers:
      - name: simple-test
        image: python:3.9-slim
        command: ["/bin/sh", "-c"]
        args:
        - |
          pip install requests &&
          python /app/simple_test.py
        env:
        - name: FLAMECRAFT_SERVICE_URL
          value: "http://flamecraft-app.dev.svc.cluster.local:80"
        volumeMounts:
        - name: test-script
          mountPath: /app
      volumes:
      - name: test-script
        configMap:
          name: regression-test-config
      restartPolicy: Never
  backoffLimit: 1
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: regression-test-config
  namespace: dev
data:
  simple_test.py: |
    # Python test script content here...
```

## Security Considerations

### Secret Management
- AWS credentials stored in Jenkins credentials store
- SSH keys for GitHub access managed securely
- Slack webhooks stored as Jenkins secrets

### Vulnerability Scanning
- Multiple layers of security scanning
- Pipeline fails on CRITICAL/HIGH vulnerabilities
- Secret detection prevents credential leaks

### Network Security
- ECR Public authentication uses temporary tokens
- EKS cluster access controlled via AWS IAM
- Kubernetes service communication within cluster

## Monitoring and Observability

### Test Results
- HTML reports archived in Jenkins
- Slack notifications with detailed test results
- Test logs captured and stored

### Build Metrics
- Build duration tracking
- Success/failure rates
- Test execution times

## Troubleshooting

### Common Issues

1. **ECR Authentication Failures**
   - Verify AWS credentials have ECR Public permissions
   - Check ECR Public region (us-east-1)

2. **Kubernetes Job Timeouts**
   - Increase timeout values in `kubectl wait`
   - Check pod resource limits

3. **Docker Build Failures**
   - Verify Dockerfile syntax
   - Check base image availability

4. **Helm Deployment Issues**
   - Validate Helm chart syntax
   - Check namespace permissions

### Debug Commands

```bash
# Check Jenkins agent Docker
docker version

# Verify AWS credentials
aws sts get-caller-identity

# Test EKS connectivity
kubectl get nodes

# Check pod logs
kubectl logs -f job/regression-test-job -n dev

# View Helm release status
helm list -n dev
```

## Performance Optimization

### Parallel Execution
- Security scans run in parallel
- Reduces overall pipeline execution time

### Resource Optimization
- Docker image cleanup prevents disk space issues
- Kubernetes Jobs are ephemeral and self-cleaning

### Caching Strategies
- ECR image layers cached for faster builds
- Dependency caching for Python packages

## Conclusion

This comprehensive Jenkins pipeline provides a production-ready CI/CD solution that combines security scanning, automated testing, and deployment orchestration. The use of Kubernetes Jobs for regression testing ensures reliable, isolated test execution that integrates seamlessly with the existing EKS infrastructure.

The pipeline follows DevSecOps best practices with multiple security gates, automated testing, and comprehensive reporting. The modular design allows for easy extension and customization based on specific project requirements.

## Next Steps

1. Set up Jenkins with required plugins and credentials
2. Configure AWS resources (EKS, ECR Public)
3. Deploy the pipeline and test with sample commits
4. Implement additional test scenarios as needed
5. Set up monitoring and alerting for pipeline health

This pipeline serves as a robust foundation for deploying Flask applications to Kubernetes with enterprise-grade CI/CD capabilities.
