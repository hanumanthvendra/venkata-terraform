bucket         = "terraform-backend-venkata"
key            = "backend/dev/terraform.tfstate"
region         = "ap-south-1"
encrypt        = true
kms_key_id     = "alias/terraform-backend"
dynamodb_table = "terraform-backend-venkata-locks"
