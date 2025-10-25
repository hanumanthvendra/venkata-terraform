# Jenkins EC2 Fleet Cloud Configuration

This document describes the configuration for the Jenkins EC2 Fleet cloud named `jenkins-slave-ec2-fleet-asg`.

## Cloud Configuration

### Basic Settings
- **Name**: `jenkins-slave-ec2-fleet-asg`
- **AWS Credentials**: `AKIA344CXSAKFSO5D5ZW` (aws-credentials-id)
- **Region**: `ap-south-1` (Asia Pacific - Mumbai)
- **EC2 Fleet**: `Auto Scaling Group - jenkins-slave-asg`

### Auto Scaling Group Details
- **ASG Name**: `jenkins-slave-asg`
- **Desired Capacity**: `1`
- **Min/Max Capacity**: `1 - 2`
- **ASG ARN**: `arn:aws:autoscaling:ap-south-1:817928572948:autoScalingGroup:bc29d485-ae7a-4498-af7d-7ba8cd5a6d3d:autoScalingGroupName/jenkins-slave-asg`

### Launch Template Configuration
- **Launch Template ID**: `lt-0eb73034fdc98e3fa`
- **Launch Template Name**: `jenkins-slave`
- **AMI ID**: `ami-0eafcd59c39408231`
- **Key Pair**: `test`
- **Security Group ID**: `sg-0c1326417f7235624`
- **Subnets**: `subnet-05da43b6d58a4a7ad`, `subnet-0d8b169af8721a3b3`
- **Availability Zones**: `ap-south-1a`, `ap-south-1b`

### Instance Type Requirements
- **t3a.medium**: 2 vCPUs, 4 GiB RAM
- **t3a.large**: 2 vCPUs, 8 GiB RAM
- **t3.large**: 2 vCPUs, 8 GiB RAM
- **t3.medium**: 2 vCPUs, 4 GiB RAM

### Instance Purchase Options
- **On-Demand**: 100%
- **Spot**: 0%
- **Allocation Strategy**: Prioritized (On-Demand), Price capacity optimized (Spot)

### Launcher Configuration
- **Launcher**: Launch agents via SSH
- **Credentials**: `ec2-user` (ec2-user-amazon-linux)
- **Host Key Verification Strategy**: Non verifying Verification Strategy

### Advanced Settings
- **Connect to instances via private IP instead of public IP**: Enabled (Private IP)
- **Always reconnect to offline nodes after instance reboot or connection loss**: Enabled (Always Reconnect)
- **Only build jobs with label expressions matching this node**: Enabled (Restrict Usage)
- **Labels to add to instances in this fleet**: `ec2-fleet`
- **Jenkins Filesystem Root**: Default `/tmp/jenkins-`
- **Number of Executors per instance**: `1`
- **Method for scaling number of executors**: No scaling
- **Max Idle Minutes Before Scaledown**: `1`
- **Minimum Cluster Size**: `1`
- **Maximum Cluster Size**: `2`
- **Minimum Spare Size**: `0`
- **Maximum Total Uses**: `-1` (unlimited)
- **Disable Build Resubmit**: Enabled (no auto-resubmit on instance termination)
- **Maximum time to wait for EC2 instance startup**: `180` seconds
- **Interval for updating EC2 cloud status**: `10` seconds
- **Enable faster provision when queue is growing**: Enabled (No Delay Provision Strategy)

## Usage

Jobs can target this cloud by using the label `ec2-fleet` in their agent configuration:

```groovy
node('ec2-fleet') {
    stage('Clean Workspace') {
        // Wipes out everything in the current workspace
        deleteDir()
    }

    stage('Check Software Versions') {
        sh 'echo "Checking software versions..."'
        sh 'java -version'
        sh 'git --version'
        sh 'docker --version'
        sh 'terraform version'
        sh 'helm version'
        sh 'packer version'
    }

    stage('Test Slave Execution') {
        sh 'echo "Running on aws ec2 fleet plugin"'
        sh 'hostname'
        sh 'whoami'
        sh 'pwd'
        sh 'ls -la'
    }
}
```

## Prerequisites

- Jenkins EC2 Fleet plugin installed
- AWS credentials configured with appropriate permissions
- Auto Scaling Group `jenkins-slave-asg` exists in `ap-south-1` region
- SSH credentials for `ec2-user` configured in Jenkins
- Network connectivity between Jenkins master and EC2 instances

## Notes

- The cloud is configured to maintain a minimum of 1 instance and maximum of 2 instances
- Instances are terminated after 1 minute of idle time
- Uses private IP connections for enhanced security
- No scaling of executors per instance (fixed at 1)
- Build resubmission is disabled for Spot instance interruptions
