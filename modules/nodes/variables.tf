variable "count" {
  description = "the number of nodes to deploy"
  default     = 1
}

variable "name" {
  description = "the name of the nodes"
}

variable "cidr" {
  description = "the cidr of the global network"
}

variable "with_external_port" {
  description = "Determines if nodes shall have a port on Ext-Net"
  default     = false
}

variable "security_group_ids" {
  description = "Security group ids to apply on ext net ports if enabled"
  default     = []
}

variable "network_id" {
  description = "the network id in which the nodes will be deployed"
}

variable "ssh_subnet_id" {
  description = "the id of the ssh subnet"
}

variable "mgmt_subnet_id" {
  description = "the id of the mgmt subnet"
}

variable "vxlan_subnet_id" {
  description = "the id of the vxlan subnet"
}

variable "vlan_subnet_id" {
  description = "the id of the vlan subnet"
}

variable "storage_subnet_id" {
  description = "the id of the storage subnet"
}

variable "internet_gw" {
  description = "the ipv4 of the internet gateway"
}

variable "ansible_public_key" {
  description = "the ssh public key that ansible will use to provision the nodes"
}

variable "image_name" {
  description = "The image name of the nodes"
  default     = "Ubuntu 16.04"
}

variable "flavor_name" {
  description = "The flavor name of the nodes"
  default     = "c2-7"
}

variable "key_pair" {
  description = "The keypair of the nodes"
}

variable "additional_storage" {
  description = "Additional storage for nodes"
  default     = 0
}

variable "lvm_vg_name" {
  description = "LVM group name for additional storage"
  default     = "cinder-volumes"
}
