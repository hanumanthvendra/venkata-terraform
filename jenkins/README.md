# Jenkins Configuration for UI-Only Management

This directory contains Helm values files for deploying Jenkins on Kubernetes with Configuration as Code (JCasC) disabled to allow persistent UI-based configurations.

## Overview

Jenkins Configuration as Code (JCasC) is a powerful feature that allows you to define Jenkins configuration in YAML files. However, when JCasC is enabled, it can overwrite manual UI changes on every pod restart, making it difficult to manage dynamic configurations like cloud providers (e.g., Amazon EC2 Fleet) through the Jenkins UI.

This setup disables JCasC completely and ensures that UI configurations persist across pod restarts.

## Problem Description

Even with `JCasC.enabled: false` in Helm values, Jenkins may still load configuration from YAML files if the `CASC_JENKINS_CONFIG` environment variable points to a directory containing JCasC YAML files. This causes:

- UI changes (e.g., adding EC2 Fleet clouds) to be overwritten on restart
- Inability to manage dynamic configurations through the Jenkins web interface
- Persistent configuration conflicts

### Root Cause

The `CASC_JENKINS_CONFIG` environment variable is set to `/var/jenkins_home/casc_configs`, and Jenkins scans this directory for YAML files on startup, re-applying any found configurations regardless of the JCasC enabled flag.

## Solution

The fix involves:

1. Disabling JCasC and auto-reload sidecars
2. Explicitly blanking the `CASC_JENKINS_CONFIG` environment variable
3. Removing any existing JCasC YAML files from the persistent volume
4. Configuring clouds and other settings through the UI

## Configuration Files

### `values.yaml`
Basic configuration with JCasC disabled but may not clear the environment variable if previously set.

### `ui-only.yaml`
Complete configuration that ensures JCasC is fully disabled and UI changes persist:

```yaml
controller:
  persistence:
    enabled: true
    existingClaim: jenkins

  # Turn off JCasC completely
  JCasC:
    enabled: false
    defaultConfig: false

  # No auto-reload sidecar
  sidecars:
    configAutoReload:
      enabled: false

  # IMPORTANT: blank out the env var so the plugin does NOT load any YAML
  containerEnv:
    - name: CASC_JENKINS_CONFIG
      value: ""
```

## Deployment Steps

1. **Apply the UI-only configuration:**

   ```bash
   helm upgrade --install jenkins jenkins/jenkins \
     -n default -f ui-only.yaml --reuse-values
   ```

2. **Wait for rollout to complete:**

   ```bash
   kubectl -n default rollout status statefulset/jenkins --timeout=5m
   ```

3. **Remove existing JCasC YAML files from the persistent volume:**

   ```bash
   kubectl -n default exec -it jenkins-0 -c jenkins -- sh -lc 'rm -f /var/jenkins_home/casc_configs/*.yaml || true'
   kubectl -n default exec -it jenkins-0 -c jenkins -- sh -lc 'ls -l /var/jenkins_home/casc_configs || true'
   ```

4. **Configure Jenkins through the UI:**

   - Navigate to Manage Jenkins → System → Clouds
   - Add your Amazon EC2 Fleet cloud with appropriate labels
   - Save the configuration

5. **Restart and verify persistence:**

   ```bash
   kubectl -n default rollout restart statefulset/jenkins
   kubectl -n default get pods -w
   ```

   After the pod is ready, confirm your cloud configuration remains in Manage Jenkins → Clouds.

## Verification

### Check Environment Variables
Ensure the `CASC_JENKINS_CONFIG` variable is not set:

```bash
kubectl -n default exec -it jenkins-0 -c jenkins -- sh -lc 'env | grep -i CASC || echo "No CASC env ✅"'
```

### Check for JCasC Sidecars
Verify no JCasC sidecars are running:

```bash
kubectl -n default get pod jenkins-0 -o jsonpath='{.spec.initContainers[*].name}{"\n"}{.spec.containers[*].name}{"\n"}' | tr ' ' '\n' | grep -E 'config-reload|jcasc' || echo "No JCasC sidecars ✅"
```

### Check Persistent Volume
Confirm no JCasC YAML files remain:

```bash
kubectl -n default exec -it jenkins-0 -c jenkins -- sh -lc 'ls -l /var/jenkins_home/casc_configs || true'
```

### Verify Mounts (if applicable)
Check for any casc_configs mounts:

```bash
kubectl -n default exec -it jenkins-0 -c jenkins -- sh -lc 'mount | grep casc_configs || echo "No casc_configs mount ✅"'
```

## Troubleshooting

### UI Changes Still Being Overwritten

- Verify `CASC_JENKINS_CONFIG` is blanked in the Helm values
- Check that all JCasC YAML files have been removed from `/var/jenkins_home/casc_configs`
- Ensure you're using `--reuse-values` if upgrading an existing release

### JCasC Sidecars Still Present

- Confirm `sidecars.configAutoReload.enabled: false` in values
- Check Helm release status: `helm -n default get values jenkins`

### Environment Variable Still Set

- The env var may persist from previous Helm revisions
- Use `ui-only.yaml` which explicitly sets it to an empty string
- Verify with: `kubectl -n default exec -it jenkins-0 -c jenkins -- env | grep -i CASC`

### Debugging Commands

Get current Helm values:
```bash
helm -n default get values jenkins
```

Get StatefulSet configuration:
```bash
kubectl -n default get statefulset jenkins -o yaml | sed -n '/env:/,/volumeMounts:/p'
```

## Notes

- This configuration is designed for scenarios where Jenkins configuration needs to be managed primarily through the UI
- For infrastructure-as-code approaches, consider re-enabling JCasC with appropriate YAML files
- Always backup your Jenkins configuration before making changes
- The `existingClaim: jenkins` assumes a pre-existing PersistentVolumeClaim for data persistence
