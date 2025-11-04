bucket         = "terraform-state-niigatacity-kaigo"
key            = "common/terraform.tfstate"
region         = "ap-northeast-1"
encrypt        = true
dynamodb_table = "terraform-state-lock"
