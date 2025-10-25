node('ec2-fleet') {
  // ---- Config ----
  def TERRAFORM_VERSION = '1.5.7'
  def AWS_REGION        = 'ap-south-1'
  def ENVIRONMENT       = 'dev'
  def WORKSPACE_DIR     = 'envs/dev/lambda'



  try {

  stage('Clean Workspace') { deleteDir() }

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



  stage('Terraform Format') {
    dir(WORKSPACE_DIR) {
      sshagent(['git-ssh-key']) {
        sh """
          set -euxo pipefail
          terraform fmt -recursive
          if [ -n "\$(git status --porcelain -- '*.tf' '*.tfvars' || true)" ]; then
            git config user.email "ci@your-org"
            git config user.name  "Jenkins CI"
            git add -A
            git commit -m "ci: terraform fmt"
            git push origin HEAD:main
            echo '✓ Auto-formatted and pushed.'
          else
            echo '✓ No formatting changes.'
          fi
        """
      }
    }
  }

  stage('Parallel Lint & Validate') {
    parallel(
      "TFLint": {
        dir(WORKSPACE_DIR) {
          sh """
            set -euxo pipefail
            docker run --rm -v "\$PWD:/data" -w /data ghcr.io/terraform-linters/tflint:latest \
              --init || true
            docker run --rm -v "\$PWD:/data" -w /data ghcr.io/terraform-linters/tflint:latest \
              --recursive || true
          """
        }
      },
      "TFsec": {
        dir(WORKSPACE_DIR) {
          sh """
            set -euxo pipefail
            docker run --rm -v "\$PWD:/src" aquasec/tfsec:latest \
              /src --format junit --out tfsec-results.xml || true
          """
          archiveArtifacts artifacts: 'tfsec-results.xml', allowEmptyArchive: true
        }
      },
      "Checkov": {
        dir(WORKSPACE_DIR) {
          sh """
            set -euxo pipefail
            docker run --rm -v "\$PWD:/tf" bridgecrew/checkov:latest \
              -d /tf --framework terraform --download-external-modules true \
              -o junitxml > checkov-results.xml || true
          """
          archiveArtifacts artifacts: 'checkov-results.xml', allowEmptyArchive: true
        }
      }
    )
  }

  stage('Terraform Validate') {
    dir(WORKSPACE_DIR) {
      withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-credentials-id']]) {
        sh """
          set -euxo pipefail
          export AWS_DEFAULT_REGION='${AWS_REGION}'
          export AWS_EC2_METADATA_DISABLED=true

          terraform init -backend-config=backend.hcl

          terraform validate
        """
      }
    }
  }

  stage('Terraform Plan') {
    dir(WORKSPACE_DIR) {
      withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-credentials-id']]) {
        sh """
          set -euxo pipefail
          export AWS_DEFAULT_REGION='${AWS_REGION}'
          export AWS_EC2_METADATA_DISABLED=true

          terraform plan -out=tfplan.binary
          terraform show -json tfplan.binary > tfplan.json
        """
        archiveArtifacts artifacts: 'tfplan.json', allowEmptyArchive: true
      }
    }
  }

  stage('Policy-as-Code on Plan (Conftest)') {
    dir(WORKSPACE_DIR) {
      sh """
        set -euxo pipefail
        if [ -d policy ] && [ -f tfplan.json ]; then
          docker run --rm -v "\$PWD:/project" openpolicyagent/conftest:latest \
            test /project/tfplan.json --parser json --policy /project/policy \
            --output junit > conftest-results.xml || true
        else
          echo "Skipping Conftest: policy/ or tfplan.json not found."
        fi
      """
      archiveArtifacts artifacts: 'conftest-results.xml', allowEmptyArchive: true
    }
  }

  stage('Infracost (Optional)') {
    script {
      if (env.INFRACOST_API_KEY) {
        dir(WORKSPACE_DIR) {
          sh """
            set -euxo pipefail
            docker run --rm -e INFRACOST_API_KEY=\$INFRACOST_API_KEY \
              -v "\$PWD:/data" -w /data infracost/infracost:latest \
              breakdown --path /data --format json --out-file infracost.json
          """
          archiveArtifacts artifacts: 'infracost.json', allowEmptyArchive: true
        }
      } else {
        echo "INFRACOST_API_KEY not set, skipping Infracost"
      }
    }
  }

  stage('Approval for Apply') {
    script {
      def userInput = input(
        id: 'ProceedToApply',
        message: 'Apply Terraform changes?',
        parameters: [
          choice(
            name: 'APPLY_CHANGES',
            choices: ['Yes', 'No'],
            description: 'Choose whether to apply the Terraform plan'
          )
        ]
      )

      if (userInput == 'Yes') {
        echo "✓ Approved for Terraform apply"
        env.APPLY_CHANGES = 'true'
      } else {
        echo "✗ Terraform apply cancelled by user"
        env.APPLY_CHANGES = 'false'
      }
    }
  }

  if (env.APPLY_CHANGES == 'true') {
    stage('Terraform Apply') {
      dir(WORKSPACE_DIR) {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                          credentialsId: 'aws-credentials-id']]) {
          sh """
            set -euxo pipefail
            export AWS_DEFAULT_REGION='${AWS_REGION}'
            export AWS_EC2_METADATA_DISABLED=true

            terraform apply tfplan.binary
          """
        }
      }
    }

    stage('Post-Apply Tests (Optional)') {
      // Add module unit tests here if needed, e.g., Kitchen-Terraform or Terratest
      echo "Running post-apply tests..."
      // Example: sh 'docker run --rm -v "$PWD:/data" -w /data some/test-image:latest'
    }

    stage('Generate Docs & Graph') {
      dir(WORKSPACE_DIR) {
        sh """
          set -euxo pipefail
          # Graphviz via container
          terraform graph | docker run --rm -i nshine/graphviz dot -Tpng > graph.png

          # terraform-docs via container
          docker run --rm -v "\$PWD:/work" -w /work quay.io/terraform-docs/terraform-docs:latest \
            markdown . > README.md
        """
        archiveArtifacts artifacts: 'graph.png, README.md', allowEmptyArchive: true
      }
    }

    stage('SBOM & License Scan') {
      dir(WORKSPACE_DIR) {
        sh """
          set -euxo pipefail
          docker run --rm -v "\$PWD:/data" -w /data anchore/syft:latest \
            /data --output spdx-json > sbom.json
          docker run --rm -v "\$PWD:/data" -w /data aquasec/trivy:latest \
            fs --format json --output trivy-results.json /data
        """
        archiveArtifacts artifacts: 'sbom.json, trivy-results.json', allowEmptyArchive: true
      }
    }
  }

  stage('Cleanup') {
    sh """
      set -euxo pipefail
      # Cleanup any temporary files if needed
    """
  }

  } catch (Exception e) {
    // Send failure notification
    withCredentials([string(credentialsId: 'slack-webhook-url', variable: 'SLACK_WEBHOOK')]) {
      sh """
        curl -X POST -H 'Content-type: application/json' \
          --data '{
            "text": "❌ Terraform Pipeline Failed - Build #${env.BUILD_NUMBER}",
            "blocks": [
              {
                "type": "section",
                "text": {
                  "type": "mrkdwn",
                  "text": "*❌ Build Failed*"
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
                    "text": "*Environment:* ${ENVIRONMENT}"
                  },
                  {
                    "type": "mrkdwn",
                    "text": "*Error:* ${e.getMessage()}"
                  }
                ]
              }
            ]
          }' \
          \$SLACK_WEBHOOK
      """
    }
    throw e
  }
}
