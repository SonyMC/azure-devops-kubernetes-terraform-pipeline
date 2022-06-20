# Script for provisioning/creating kubernetes cluster
# aws --version
# aws eks --region us-east-1 update-kubeconfig --name mailsonymathews-cluster
# Uses default VPC and Subnet. Create Your Own VPC and Private Subnets for Prod Usage.
# S3 bucket ARN : arn:aws:s3:::terraform-backend-state-mailsonymathew
# S3 bucket name : terraform-backend-state-mailsonymathew
# IAM user : cmd line user access id: AKIASQFSB4RYYVUR2HIN
# Default vpc : aws -> services -> vpc -> default vpc is thw one without a name -> copy id -> vpc-eec60593
# subnet -> go to defaulr vpc ( refer above) -> select it -> select subnets from the left tab under 'virtual private cloud' 
# subnet ids -> subnet-d58c3ef4, subnet-84b80fe2

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}
 
# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  # VERSION IS NOT NEEDED HERE
} 


# S3 bucket dummy values defintion which will be automtically overwritten while executing the Azure Devops pipeline
terraform {
  backend "s3" {
    bucket = "mybucket" # dummy value which lill be overridden during pipeline execution 
    key    = "path/to/my/key" # dummy value which will be overridden during pipeline execution  
    region = "us-east-1" # dummy value which will be overridden during pipeline execution  
  }
}

resource "aws_default_vpc" "default" {

}

data "aws_subnet_ids" "subnets" {
  vpc_id = aws_default_vpc.default.id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
#  version                = "~> 1.9"
}

module "mailsonymathew-cluster" {
  source          = "terraform-aws-modules/eks/aws"     # Uses module in   https://github.com/terraform-aws-modules/terraform-aws-eks to create AWS EKS
  cluster_name    = "mailsonymathew-cluster"
  cluster_version = "1.22"   # For latest versions refer : https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
  vpc_id          = aws_default_vpc.default.id   # default VPC
  #vpc_id         = "vpc-eec60593"
  subnet_ids         = ["subnet-d58c3ef4", "subnet-84b80fe2"] #CHANGE
  #subnets = data.aws_subnet_ids.subnets.ids


#  node_groups = [
#    {
#      instance_type = "t2.micro"
#      max_capacity  = 5
#      desired_capacity = 2
#      min_capacity  = 2
#    }
#  ]
#

  # Self Managed Node Group(s)
  self_managed_node_group_defaults = {
    instance_type  = "t2.micro"
    max_capacity  = 5
    desired_capacity = 2
    min_capacity  = 2
  }

}

data "aws_eks_cluster" "cluster" {
  name = module.mailsonymathew-cluster.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.mailsonymathew-cluster.cluster_id
}


# We will use ServiceAccount to connect to K8S Cluster in CI/CD mode
# ServiceAccount needs permissions to create deployments and services in default namespace
resource "kubernetes_cluster_role_binding" "example" {
  metadata {
    name = "fabric8-rbac"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"  # Though admin role is provided here for demo we usually provide very specific persmissions.
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "default"
  }
}

# Needed to set the default region
#provider "aws" {
#  region  = "us-east-1"
#}