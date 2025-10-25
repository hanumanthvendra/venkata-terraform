
          set -euxo pipefail
          terraform fmt -recursive
          if [ -n "$(git status --porcelain -- '*.tf' '*.tfvars' || true)" ]; then
            git config user.email "ci@your-org"
            git config user.name  "Jenkins CI"
            git add -A
            git commit -m "ci: terraform fmt"
            git push origin HEAD:main
            echo '✓ Auto-formatted and pushed.'
          else
            echo '✓ No formatting changes.'
          fi
        