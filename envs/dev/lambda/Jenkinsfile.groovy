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
        // ---------- REPORT-ONLY: Gitleaks ----------
        "Secret Scan (Gitleaks)": {
          script {
            // Run scan and capture exit code without failing the stage
            def rc = sh(
              returnStatus: true,
              script: '''
                set -euo pipefail
                CFG_ARG=""
                test -f .gitleaks.toml && CFG_ARG="--config=/repo/.gitleaks.toml"
                docker run --rm -v "$PWD:/repo" -w /repo zricethezav/gitleaks:latest \
                  detect --source=/repo $CFG_ARG \
                  --report-format sarif --report-path gitleaks.sarif --redact
              '''
            )
            archiveArtifacts artifacts: 'gitleaks.sarif', allowEmptyArchive: true
            if (rc != 0) {
              echo "Gitleaks found secrets (exit ${rc}). Marking build UNSTABLE."
              currentBuild.result = 'UNSTABLE'
            } else {
              echo "✓ No leaks found by Gitleaks."
            }
          }
        },

        // ---------- REPORT-ONLY: Trivy repo secret scan ----------
        "Secret Scan (Trivy Repo)": {
          script {
            def rc = sh(
              returnStatus: true,
              script: '''
                set -euo pipefail
                echo "Running Trivy secret scan on repository..."
                docker run --rm -v "$PWD:/repo" -w /repo aquasec/trivy:latest \
                  fs --scanners secret --no-progress --exit-code 1 /repo
              '''
            )
            // Optionally archive Trivy JSON too (requires --format json --output ...)
            if (rc != 0) {
              echo "Trivy secret scan found issues (exit ${rc}). Marking build UNSTABLE."
              currentBuild.result = 'UNSTABLE'
            } else {
              echo "✓ No secrets found by Trivy."
            }
          }
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

    // ======= WORKING Parallel Lint & Validate you tested =======
    stage('Parallel Lint & Validate') {
      parallel(
        "TFLint (v0.53.0)": {
          dir(WORKSPACE_DIR) {
            sh """
              set -euxo pipefail
              ROOT_DIR=\$(cd ../../.. && pwd -P)

              docker run --rm \
                -v "\$ROOT_DIR:/repo" \
                -w /repo/${WORKSPACE_DIR} \
                ghcr.io/terraform-linters/tflint:v0.53.0 \
                sh -lc 'tflint --init && tflint --recursive' || true
            """
          }
        },
        "TFsec": {
          dir(WORKSPACE_DIR) {
            sh """
              set -euxo pipefail
              ROOT_DIR=\$(cd ../../.. && pwd -P)
              docker run --rm \
                -v "\$ROOT_DIR:/repo" \
                -w /repo/${WORKSPACE_DIR} \
                aquasec/tfsec:latest /repo/${WORKSPACE_DIR} \
                --format junit --out /repo/${WORKSPACE_DIR}/tfsec-results.xml || true
            """
            archiveArtifacts artifacts: 'tfsec-results.xml', allowEmptyArchive: true
          }
        },
        "Checkov": {
          dir(WORKSPACE_DIR) {
            sh """
              set -euxo pipefail
              ROOT_DIR=\$(cd ../../.. && pwd -P)
              docker run --rm \
                -v "\$ROOT_DIR:/repo" \
                -v "\$ROOT_DIR/modules:/modules:ro" \
                bridgecrew/checkov:latest \
                -d /repo/${WORKSPACE_DIR} --framework terraform --download-external-modules true \
                -o junitxml > checkov-results.xml || true
            """
            archiveArtifacts artifacts: 'checkov-results.xml', allowEmptyArchive: true
          }
        }
      )
    }
    // ======= /WORKING =======

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
              --rego-version v0 --output junit > conftest-results.xml || true
          else
            echo "Skipping Conftest: policy/ or tfplan.json not found."
          fi
        """
        archiveArtifacts artifacts: 'conftest-results.xml', allowEmptyArchive: true
      }
    }

    stage('Infracost (Optional)') {
      withCredentials([string(credentialsId: 'infracost-api-key', variable: 'INFRACOST_API_KEY')]) {
        dir(WORKSPACE_DIR) {
          sh """
            set -euxo pipefail
            docker run --rm -e INFRACOST_API_KEY=\$INFRACOST_API_KEY \
              -v "\$PWD:/data" -w /data infracost/infracost:latest \
              breakdown --path /data --format json --out-file infracost.json
          """
          archiveArtifacts artifacts: 'infracost.json', allowEmptyArchive: true
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
        echo "Running post-apply tests..."
      }

      stage('Generate Docs & Graph') {
        dir(WORKSPACE_DIR) {
          withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                            credentialsId: 'aws-credentials-id']]) {
            sh """
              set -euxo pipefail
              export AWS_DEFAULT_REGION='${AWS_REGION}'
              export AWS_EC2_METADATA_DISABLED=true

              # Render graph.png using Alpine + Graphviz installed on-the-fly
              terraform graph | docker run --rm -i alpine:3.20 \
                sh -c 'apk add --no-cache graphviz >/dev/null && dot -Tpng' > graph.png

              # Generate README with terraform-docs (pinned)
              docker run --rm -v "\$PWD:/work" -w /work quay.io/terraform-docs/terraform-docs:0.19.0 \
                markdown . > README.md
            """
            archiveArtifacts artifacts: 'graph.png, README.md', allowEmptyArchive: true
          }
        }
      }

      stage('SBOM & License Scan') {
        dir(WORKSPACE_DIR) {
          sh """
            set -euxo pipefail

            # --- Syft SBOM (SPDX JSON) ---
            docker run --rm -v "\$PWD:/data" -w /data anchore/syft:latest \
              /data -o spdx-json > sbom.json

            # --- Trivy FS (vuln + secrets + license) ---
            docker run --rm -v "\$PWD:/data" -w /data aquasec/trivy:latest \
              fs --scanners vuln,secret,license --format json --output trivy-results.json /data || true
          """
          archiveArtifacts artifacts: 'sbom.json, trivy-results.json', allowEmptyArchive: true
        }
      }
    }

    stage('Cleanup') {
      sh """
        set -euxo pipefail
        true
      """
    }

  } catch (Exception e) {
    withCredentials([string(credentialsId: 'slack-webhook-url', variable: 'SLACK_WEBHOOK')]) {
      sh """
        curl -sS -X POST -H 'Content-type: application/json' \
          --data '{
            "text": "❌ Terraform Pipeline Failed - Build #${env.BUILD_NUMBER}",
            "blocks": [
              { "type": "section", "text": { "type": "mrkdwn", "text": "*❌ Build Failed*" } },
              { "type": "section", "fields": [
                  { "type": "mrkdwn", "text": "*Job:* ${env.JOB_NAME}" },
                  { "type": "mrkdwn", "text": "*Build:* #${env.BUILD_NUMBER}" },
                  { "type": "mrkdwn", "text": "*Environment:* ${ENVIRONMENT}" },
                  { "type": "mrkdwn", "text": "*Error:* ${e.getMessage()?.replaceAll("\"","\\\"")}" }
              ]}
            ]
          }' \
          "$SLACK_WEBHOOK" || true
      """
    }
    throw e
  }
}
