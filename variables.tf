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
    queens = "17.0.4"
    pike   = "17.0.13"
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
    compute = "c2-7"
    shared  = "b2-15"
    storage = "c2-7"
    haproxy = "c2-7"
  }
}

variable "compute_count" {
  description = "number of compute nodes"
  default     = 1
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
