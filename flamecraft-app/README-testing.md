# Flamecraft App Regression Testing

This document describes the regression test suite for the Flamecraft Flask API application.

## Overview

The regression test suite is designed to test the Flask API endpoints in a Kubernetes environment where the service is not exposed externally. Tests run against the internal service URL within the same VPC/cluster.

## Test Structure

### Test File: `test_regression.py`

The test suite includes comprehensive tests for:

- **Health Checks**: `/health` and `/ready` endpoints
- **Employee CRUD Operations**:
  - GET `/employees` (list all, sanitized)
  - GET `/employees/<id>` (single employee, sanitized)
  - POST `/employees` (create new employee)
  - PUT `/employees/<id>` (update employee)
  - DELETE `/employees/<id>` (delete employee)
- **Security Features**:
  - Input validation
  - Request size limiting
  - Error handling

### Test Configuration

- **Service URL**: Configurable via `FLAMECRAFT_SERVICE_URL` environment variable
- **Default URL**: `http://flamecraft-app.dev.svc.cluster.local:5500`
- **Timeout**: 10 seconds per request

## Running Tests

### Option 1: Local Testing (if service is accessible)

```bash
# Install dependencies
pip install -r requirements.txt

# Set service URL (optional, uses default if not set)
export FLAMECRAFT_SERVICE_URL="http://localhost:5500"

# Run tests
pytest test_regression.py -v
```

### Option 2: Kubernetes Job

1. **Build test image**:
   ```bash
   docker build -f Dockerfile.test -t flamecraft:test .
   ```

2. **Push to registry** (if needed):
   ```bash
   docker tag flamecraft:test your-registry/flamecraft:test
   docker push your-registry/flamecraft:test
   ```

3. **Update test-job.yaml** with correct image reference

4. **Run the test job**:
   ```bash
   kubectl apply -f test-job.yaml
   ```

5. **Check results**:
   ```bash
   kubectl logs job/flamecraft-regression-test
   kubectl get job flamecraft-regression-test
   ```

### Option 3: Using kubectl exec (Direct pod testing)

If you need to run tests from within the cluster:

```bash
# Get a pod running the test image
kubectl run test-runner --image=flamecraft:test --restart=Never --rm -it -- /bin/bash

# Inside the pod, run tests
pytest test_regression.py -v
```

## Integration with CI/CD

The test suite is designed to integrate with Jenkins pipelines (see `Jenkinsfile-testing` for an example).

### Jenkins Integration

The `Jenkinsfile-testing` includes:
- Building and pushing test images
- Running regression tests against deployed service
- Generating test reports
- Email notifications
- Slack notifications

## Test Data Management

- Tests assume the application uses in-memory storage
- Tests create, update, and delete test data
- No persistent data is assumed or required
- Tests are idempotent and can run multiple times

## Security Considerations

- Tests run against internal service endpoints only
- No external exposure required
- Tests validate security features like input validation and size limits

## Dependencies

- `pytest`: Test framework
- `requests`: HTTP client for API testing

## Environment Variables

- `FLAMECRAFT_SERVICE_URL`: Override default service URL (default: internal cluster DNS)

## Troubleshooting

### Common Issues

1. **Connection refused**: Ensure service is running and accessible from test pod
2. **DNS resolution**: Verify cluster DNS configuration for service discovery
3. **Timeout errors**: Check network policies and service mesh configuration
4. **Permission denied**: Ensure test pods have necessary RBAC permissions

### Debugging

```bash
# Test connectivity from within cluster
kubectl run debug --image=curlimages/curl --rm -it -- curl http://flamecraft-app.dev.svc.cluster.local:5500/health

# Check service endpoints
kubectl get svc -n dev
kubectl describe svc flamecraft-app -n dev
```

## Future Enhancements

- Add performance/load testing
- Integrate with monitoring systems
- Add database state validation (if persistent storage is added)
- Implement test data fixtures for complex scenarios
