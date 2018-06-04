variable "name" {
  description = "name of openstack project"
  default     = "myopenstack"
}

variable "version" {
  description = "version of openstack to deploy; latest or queens, pike, ocata"
  default     = "queens"
}

variable "openstack_versions" {
  description = "map of openstack versions against openstack-ansible branches"

  default = {
    queens = "stable/queens"
    pike   = "16.0.13"
    ocata  = "15.1.21"
    latest = "master"
  }
}

variable "project_id" {
  description = "The id of the cloud project"
}

variable "cidr" {
  description = "The global network cidr that will be sub divided for openstack needs"
  default     = "172.29.0.0/16"
}

variable "vlan_cidr" {
  description = "The network cidr for the vlan range"
  default     = "172.30.0.0/16"
}

variable "region" {
  description = "The target openstack region"
  default     = "GRA3"
}

variable "ssh_public_key" {
  description = "The path of the ssh public key that will be used by ansible to provision the hosts"
  default     = "~/.ssh/id_rsa.pub"
}

variable "flavor_name" {
  description = "The flavor name used for the hosts"
  default     = "c2-7"
}

variable "flavor_names" {
  description = "a map of flavor names per node."
  type        = "map"

  default = {
    nat     = "s1-4"
    bastion = "s1-2"
    compute = "b2-30"
    shared  = "b2-15"
    storage = "c2-7"
    haproxy = "c2-7"
  }
}

variable "compute_count" {
  description = "number of compute nodes"
  default     = 3
}

variable "cinder_count" {
  description = "number of cinder nodes"
  default     = 1
}

variable "swift_count" {
  description = "number of swift nodes"
  default     = 1
}

variable "cinder_host_storage" {
  description = "default additional volume size. < 1 means no additional volume"
  default     = 10
}

variable "password" {
  description = "the password used for all subsystem of openstack"
  default     = "zoblesmouches42"
}

variable "cinder_container_vars" {
  description = "the cinder container vars"

  default = <<EOF
container_vars:
  cinder_backends:
    lvm:
      volume_backend_name: LVM_iSCSI
      volume_driver: cinder.volume.drivers.lvm.LVMVolumeDriver
      volume_group: cinder-volumes
      iscsi_ip_address: "{{ cinder_storage_address }}"
    limit_container_types: cinder_volume
EOF
}

variable "provider_net_name" {
  description = "the provider external network name"
  default     = "GATEWAY_NET"
}

variable "provider_net_cidr" {
  description = "the provider external network cidr"
  default    = "10.0.248.0/22"
}

variable "provider_dns_server" {
  description = "the provider external network dns server"
  default    = "213.186.33.99"
}

variable "provider_subnet_gw" {
  description = "the provider external network gateway. if left blank, first ip of the network will be used"
  default    = ""
}

variable "provider_subnet_pool_start" {
  description = "the provider external network pool start. if left blank, first ip of the network will be used"
  default    = ""
}

variable "provider_subnet_pool_end" {
  description = "the provider external network pool end. if left blank, last ip of the subnet will be used"
  default    = ""
}

variable "provider_subnet_enable_dhcp" {
  description = "determines if a dhcp agent should be enable for the provider subnet"
  default    = true
}
