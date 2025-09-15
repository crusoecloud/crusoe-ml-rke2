variable "ssh_pubkey" {
  description = "The ssh public key to use for the instances"
}

variable "ssh_privkey_path" {
  description = "The path to the ssh private key to auth to the instances"
}

#An up-to-date list of supported Crusoe Cloud images can be found at -> https://docs.crusoecloud.com/compute/images/overview 
variable "headnode_image" {
  description = "The image to use for creating the headnode instance"
  default     = "ubuntu22.04:latest"
}

#Supported VM types can be found here -> https://docs.crusoecloud.com/compute/virtual-machines/overview
variable "headnode_instance_type" {
  description = "Name of the instance type to use for the headnode instance"
  default     = "c1a.8x"
}

variable "headnode_count" {
  description = "How many headnodes to use, 1 implies no loadbalancing"
}

variable "worker_image" {
  description = "The image to use for creating the worker instances"
  default     = "ubuntu22.04-nvidia-pcie-docker:latest"
}

variable "worker_instance_type" {
  description = "Name of the instance type to use for the worker instances"
}

variable "worker_count" {
  description = "Number of worker instances to create"
  default     = 1
}

variable "ib_partition_id" {
  description = "infiniband partition id to use for the cluster"
}

#Currently supported regions are us-east1-a, us-northcentral1-a and us-southcentral1-a
variable "deploy_location" {
  description = "region to deploy the cluster in"
  default     = "us-east1-a"
}

variable "instance_name_prefix" {
  description = "Prefix to use for the instance names"
  default     = "crusoe"
}

variable "enable_dra_feature" {
  description = "Add extra config settings for DynamicResourceAllocation for GB200s"
  type        = bool
  default     = false
}

variable "rke_version" {
  description = "RKE2 version to install"
  type        = string
  default     = "v1.32.6+rke2r1"  # default
}