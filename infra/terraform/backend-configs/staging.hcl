bucket         = "terraform-state-niigatacity-kaigo"
key            = "staging/terraform.tfstate"
region         = "ap-northeast-1"
encrypt        = true
dynamodb_table = "terraform-state-lock"
