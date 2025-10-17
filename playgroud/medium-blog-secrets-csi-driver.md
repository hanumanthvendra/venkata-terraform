# How to Deploy and Use AWS Secrets Store CSI Driver on EKS

In this blog post, I will share my experience deploying the AWS Secrets Store CSI Driver on an Amazon EKS cluster. This driver allows Kubernetes pods to securely access secrets stored in AWS Secrets Manager by mounting them as volumes inside pods.

## What is Secrets Store CSI Driver?

The Secrets Store Container Storage Interface (CSI) driver enables Kubernetes to mount secrets, keys, and certificates stored in external secret management systems into pods as volumes. AWS provides a provider for this driver to integrate with AWS Secrets Manager.

## Prerequisites

- An Amazon EKS cluster up and running
- AWS CLI configured with appropriate permissions
- kubectl configured to access the EKS cluster

## Deployment Steps

### 1. Install the Secrets Store CSI Driver

You can install the driver using Helm or kubectl. For example:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/secrets-store-csi-driver/main/deploy/rbac-secretproviderclass.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/secrets-store-csi-driver/main/deploy/csidriver.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/secrets-store-csi-driver/main/deploy/secrets-store.csi.x-k8s.io_secretproviderclasses.yaml
```

### 2. Deploy the AWS Provider

Deploy the AWS provider for the Secrets Store CSI driver:

```bash
kubectl apply -f https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml
```

### 3. Create a SecretProviderClass

Create a SecretProviderClass resource that defines which secrets to fetch from AWS Secrets Manager. Example:

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: aws-secrets-test
spec:
  provider: aws
  parameters:
    usePodIdentity: "true"
    region: "ap-south-1"
    objects: |
      - objectName: "test-secret"
        objectType: "secretsmanager"
```

### 4. Create a Pod that Uses the Secret

Create a pod spec that mounts the secret as a volume:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secrets-pod
spec:
  serviceAccountName: secrets-sa
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: secrets-store-inline
      mountPath: "/mnt/secrets"
      readOnly: true
  volumes:
  - name: secrets-store-inline
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: "aws-secrets-test"
```

### 5. Verify the Secret is Mounted

Exec into the pod and check the mounted secret:

```bash
kubectl exec -it secrets-pod -- ls /mnt/secrets
kubectl exec -it secrets-pod -- cat /mnt/secrets/test-secret
```

## Conclusion

The AWS Secrets Store CSI driver provides a secure and seamless way to inject secrets from AWS Secrets Manager into Kubernetes pods. This eliminates the need to store secrets in Kubernetes secrets and improves security posture.

Feel free to reach out if you want the full YAML manifests or help with deployment!

---

*This blog post was inspired by my recent deployment of the Secrets Store CSI driver on an EKS cluster.*
