provider "ovh" {
  endpoint = "ovh-eu"
}

provider "openstack" {
  version     = "~> 1.2"
  user_name   = "${ovh_publiccloud_user.openstack.username}"
  password    = "${ovh_publiccloud_user.openstack.password}"
  tenant_name = "${lookup(ovh_publiccloud_user.openstack.openstack_rc, "OS_TENANT_NAME")}"
  auth_url    = "${lookup(ovh_publiccloud_user.openstack.openstack_rc, "OS_AUTH_URL")}"
  region      = "${var.region}"
}

resource "ovh_publiccloud_user" "openstack" {
  project_id  = "${var.project_id}"
  description = "The openstack user used to bootstrap openstack on openstack"
}

resource "openstack_compute_keypair_v2" "keypair" {
  name       = "${var.name}_deploy"
  public_key = "${file(var.ssh_public_key)}"
}

resource "tls_private_key" "deployer" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# get NATed IP to allow ssh only from terraform host
data "http" "myip" {
  url = "https://api.ipify.org"
}

resource "openstack_networking_secgroup_v2" "lb" {
  name        = "${var.name}_lb"
  description = "${var.name} security group for ingress lb"
}

resource "openstack_networking_secgroup_rule_v2" "in_traffic_lb" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "${trimspace(data.http.myip.body)}/32"
  security_group_id = "${openstack_networking_secgroup_v2.lb.id}"
}

# allow remote ssh connection only for terraform host
resource "openstack_networking_secgroup_rule_v2" "in_traffic_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  remote_ip_prefix  = "${trimspace(data.http.myip.body)}/32"
  port_range_min    = 22
  port_range_max    = 22
  security_group_id = "${module.network.nat_security_group_id}"
}

module "network" {
  source  = "ovh/publiccloud-network/ovh"
  version = ">= 0.1"

  name   = "${var.name}"
  cidr   = "${var.cidr}"
  region = "${var.region}"

  public_subnets = ["${cidrsubnet(var.cidr, 4, 0)}"]

  private_subnets = [
    # ssh
    "${cidrsubnet(var.cidr, 4, 1)}",

    # mgmt
    "${cidrsubnet(var.cidr, 4, 2)}",

    # vxlan/tunnel
    "${cidrsubnet(var.cidr, 4, 3)}",

    # vlan
    "${cidrsubnet(var.cidr, 4, 4)}",

    # storage
    "${cidrsubnet(var.cidr, 4, 5)}",
  ]

  enable_nat_gateway           = true
  single_nat_gateway           = true
  nat_as_bastion               = true
  nat_instance_flavor_name     = "c2-7"
  key_pair                     = "${openstack_compute_keypair_v2.keypair.name}"
  nat_instance_flavor_name     = "${lookup(var.flavor_names, "nat", var.flavor_name)}"
  bastion_instance_flavor_name = "${lookup(var.flavor_names, "bastion", var.flavor_name)}"
}

# infra hosts will hosts
# shared infra hosts including the Galera SQL database cluster, RabbitMQ, and Memcached. Recommend
# repo infra hosts on which to deploy the package repository.
# os infra hosts on which to deploy the glance API, nova API, heat API and horizon
# identity hosts on which to deploy the keystone service
# network hosts on which to deploy neutron services
module "shared_infra_nodes" {
  source             = "modules/nodes"
  count              = 3
  name               = "${var.name}_shared_infra"
  cidr               = "${var.cidr}"
  network_id         = "${module.network.network_id}"
  ssh_subnet_id      = "${module.network.private_subnets[0]}"
  mgmt_subnet_id     = "${module.network.private_subnets[1]}"
  vxlan_subnet_id    = "${module.network.private_subnets[2]}"
  vlan_subnet_id     = "${module.network.private_subnets[3]}"
  storage_subnet_id  = "${module.network.private_subnets[4]}"
  internet_gw        = "${module.network.nat_private_ips[0]}"
  ansible_public_key = "${tls_private_key.deployer.public_key_openssh}"
  flavor_name        = "${lookup(var.flavor_names, "shared", var.flavor_name)}"
  key_pair           = "${openstack_compute_keypair_v2.keypair.name}"
}

# compute hosts
module "compute_nodes" {
  source             = "modules/nodes"
  count              = "${var.compute_count}"
  name               = "${var.name}_compute"
  cidr               = "${var.cidr}"
  network_id         = "${module.network.network_id}"
  ssh_subnet_id      = "${module.network.private_subnets[0]}"
  mgmt_subnet_id     = "${module.network.private_subnets[1]}"
  vxlan_subnet_id    = "${module.network.private_subnets[2]}"
  vlan_subnet_id     = "${module.network.private_subnets[3]}"
  storage_subnet_id  = "${module.network.private_subnets[4]}"
  internet_gw        = "${module.network.nat_private_ips[0]}"
  ansible_public_key = "${tls_private_key.deployer.public_key_openssh}"
  flavor_name        = "${lookup(var.flavor_names, "compute", var.flavor_name)}"
  key_pair           = "${openstack_compute_keypair_v2.keypair.name}"
}

module "cinder_nodes" {
  source             = "modules/nodes"
  count              = "${var.cinder_count}"
  name               = "${var.name}_cinder"
  cidr               = "${var.cidr}"
  network_id         = "${module.network.network_id}"
  ssh_subnet_id      = "${module.network.private_subnets[0]}"
  mgmt_subnet_id     = "${module.network.private_subnets[1]}"
  vxlan_subnet_id    = "${module.network.private_subnets[2]}"
  vlan_subnet_id     = "${module.network.private_subnets[3]}"
  storage_subnet_id  = "${module.network.private_subnets[4]}"
  internet_gw        = "${module.network.nat_private_ips[0]}"
  ansible_public_key = "${tls_private_key.deployer.public_key_openssh}"
  flavor_name        = "${lookup(var.flavor_names, "compute", var.flavor_name)}"
  key_pair           = "${openstack_compute_keypair_v2.keypair.name}"
  additional_storage = "${var.cinder_host_storage}"
}

# haproxy hosts
module "haproxy_nodes" {
  source             = "modules/nodes"
  name               = "${var.name}_haproxy"
  cidr               = "${var.cidr}"
  with_external_port = true
  security_group_ids = ["${openstack_networking_secgroup_v2.lb.id}"]
  network_id         = "${module.network.network_id}"
  ssh_subnet_id      = "${module.network.private_subnets[0]}"
  mgmt_subnet_id     = "${module.network.private_subnets[1]}"
  vxlan_subnet_id    = "${module.network.private_subnets[2]}"
  vlan_subnet_id     = "${module.network.private_subnets[3]}"
  storage_subnet_id  = "${module.network.private_subnets[4]}"
  internet_gw        = "${module.network.nat_private_ips[0]}"
  ansible_public_key = "${tls_private_key.deployer.public_key_openssh}"
  flavor_name        = "${lookup(var.flavor_names, "haproxy", var.flavor_name)}"
  key_pair           = "${openstack_compute_keypair_v2.keypair.name}"
}

data "template_file" "openstack_user_config" {
  template = "${file("openstack_user_config.yml.tpl")}"

  vars {
    cidr_network_container = "${cidrsubnet(var.cidr, 4, 2)}"
    cidr_network_tunnel    = "${cidrsubnet(var.cidr, 4, 3)}"
    cidr_network_storage   = "${cidrsubnet(var.cidr, 4, 5)}"

    external_lb_vip_address = "${element(coalescelist(module.haproxy_nodes.ext_ip_v4, module.haproxy_nodes.mgmt_ip_v4), 0)}"
    internal_lb_vip_address = "${element(module.haproxy_nodes.mgmt_ip_v4, 0)}"


    shared_infra_hosts  = "${indent(2, join( "\n", formatlist("%s:\n  ip: %s", module.shared_infra_nodes.names, module.shared_infra_nodes.access_ip_v4)))}"
    repo_infra_hosts    = "${indent(2, join( "\n", formatlist("%s:\n  ip: %s", module.shared_infra_nodes.names, module.shared_infra_nodes.access_ip_v4)))}"
    os_infra_hosts      = "${indent(2, join( "\n", formatlist("%s:\n  ip: %s", module.shared_infra_nodes.names, module.shared_infra_nodes.access_ip_v4)))}"
    storage_infra_hosts = "${indent(2, join( "\n", formatlist("%s:\n  ip: %s", module.shared_infra_nodes.names, module.shared_infra_nodes.access_ip_v4)))}"
    identity_hosts      = "${indent(2, join( "\n", formatlist("%s:\n  ip: %s", module.shared_infra_nodes.names, module.shared_infra_nodes.access_ip_v4)))}"
    network_hosts       = "${indent(2, join( "\n", formatlist("%s:\n  ip: %s", module.shared_infra_nodes.names, module.shared_infra_nodes.access_ip_v4)))}"

    compute_hosts       = "${indent(2, join( "\n", formatlist("%s:\n  ip: %s", module.compute_nodes.names, module.compute_nodes.access_ip_v4)))}"
    storage_hosts       = "${indent(2, join( "\n", formatlist("%s:\n  ip: %s\n  %s", module.cinder_nodes.names, module.cinder_nodes.access_ip_v4, indent(2, var.cinder_container_vars))))}"
    haproxy_hosts = "${indent(2, join( "\n", formatlist("%s:\n  ip: %s", module.haproxy_nodes.names, module.haproxy_nodes.access_ip_v4)))}"
  }
}

data "template_file" "deployer" {
  template = <<CLOUDCONFIG
#cloud-config
network:
    version: 2
    ethernets:
        ens3:
            dhcp4: true
            set-name: ens3
write_files:
  - path: /root/.ssh/id_rsa
    permissions: '0600'
    content: |
      ${indent(6,tls_private_key.deployer.private_key_pem)}
  - path: /root/.ssh/id_rsa.pub
    permissions: '0600'
    content: |
      ${indent(6,tls_private_key.deployer.public_key_openssh)}
CLOUDCONFIG
}

resource "openstack_networking_port_v2" "deployer_ssh" {
  name           = "${var.name}_deployer"
  network_id     = "${module.network.network_id}"
  admin_state_up = "true"

  fixed_ip {
    subnet_id = "${module.network.private_subnets[0]}"
  }
}

resource "openstack_compute_instance_v2" "deployer" {
  name        = "${var.name}_deployer"
  image_name  = "Ubuntu 16.04"
  flavor_name = "${var.flavor_name}"
  key_pair    = "${openstack_compute_keypair_v2.keypair.name}"
  user_data   = "${data.template_file.deployer.rendered}"

  network {
    access_network = true
    port           = "${openstack_networking_port_v2.deployer_ssh.id}"
  }
}

resource "null_resource" "provision" {
  # Changes to any instance of the cluster requires re-provisioning
  triggers {
    template            = "${md5(data.template_file.openstack_user_config.rendered)}"
    deployer_id         = "${openstack_compute_instance_v2.deployer.id}"
  }

  connection {
    type = "ssh"
    host = "${openstack_compute_instance_v2.deployer.access_ip_v4}"
    user = "ubuntu"
    bastion_host = "${module.network.bastion_public_ip}"
    bastion_user = "core"
  }

  provisioner "file" {
    content     = "${data.template_file.openstack_user_config.rendered}"
    destination = "/tmp/openstack_user_config.yml"
  }

  # https://docs.openstack.org/project-deploy-guide/openstack-ansible/latest/deploymenthost.html#install-the-source-and-dependencies
  provisioner "remote-exec" {
    inline = [
      "sudo git clone -b ${lookup(var.openstack_versions, var.version, "master")} https://github.com/openstack/openstack-ansible.git /opt/openstack-ansible",
      "sudo /opt/openstack-ansible/scripts/bootstrap-ansible.sh",
      "sudo cp -Rf /opt/openstack-ansible/etc/openstack_deploy /etc",
      "sudo cp /tmp/openstack_user_config.yml /etc/openstack_deploy",
      "sudo /opt/openstack-ansible/scripts/pw-token-gen.py --file /etc/openstack_deploy/user_secrets.yml",
    ]
  }
}

resource "null_resource" "ansible_setup_hosts" {
  # Changes to any instance of the cluster requires re-provisioning
  triggers {
    deployer_id         = "${null_resource.provision.id}"
    shared_infra_hosts  = "${join( ",", module.shared_infra_nodes.ids)}"
    compute_hosts       = "${join( ",", module.compute_nodes.ids)}"
    storage_hosts       = "${join( ",", module.cinder_nodes.ids)}"
    haproxy_infra_hosts = "${join( ",", module.haproxy_nodes.ids)}"
  }

  connection {
    type = "ssh"
    host = "${openstack_compute_instance_v2.deployer.access_ip_v4}"
    user = "ubuntu"
    bastion_host = "${module.network.bastion_public_ip}"
    bastion_user = "core"
  }

  # https://docs.openstack.org/project-deploy-guide/openstack-ansible/latest/run-playbooks.html#checking-the-integrity-of-the-configuration-files
  # https://docs.openstack.org/project-deploy-guide/openstack-ansible/latest/run-playbooks.html#run-the-playbooks-to-install-openstack
  provisioner "remote-exec" {
    inline = [
      "(cd /opt/openstack-ansible/playbooks && sudo openstack-ansible setup-hosts.yml --syntax-check)",
      "(cd /opt/openstack-ansible/playbooks && sudo openstack-ansible setup-hosts.yml)",
    ]
  }
}

resource "null_resource" "ansible_setup_infrastructure" {
  # Changes to setup hosts triggers re-provisioning infrastructure
  triggers {
    setup_hosts_id         = "${null_resource.ansible_setup_hosts.id}"
  }

  connection {
    type = "ssh"
    host = "${openstack_compute_instance_v2.deployer.access_ip_v4}"
    user = "ubuntu"
    bastion_host = "${module.network.bastion_public_ip}"
    bastion_user = "core"
  }

  # https://docs.openstack.org/project-deploy-guide/openstack-ansible/latest/run-playbooks.html#checking-the-integrity-of-the-configuration-files
  # https://docs.openstack.org/project-deploy-guide/openstack-ansible/latest/run-playbooks.html#run-the-playbooks-to-install-openstack
  provisioner "remote-exec" {
    inline = [
      "(cd /opt/openstack-ansible/playbooks && sudo openstack-ansible setup-infrastructure.yml --syntax-check)",
      "(cd /opt/openstack-ansible/playbooks && sudo openstack-ansible setup-infrastructure.yml)",
    ]
  }
}

resource "null_resource" "ansible_setup_openstack" {
  # Changes to setup hosts triggers re-provisioning infrastructure
  triggers {
    setup_infrastructure_id         = "${null_resource.ansible_setup_infrastructure.id}"
  }

  connection {
    type = "ssh"
    host = "${openstack_compute_instance_v2.deployer.access_ip_v4}"
    user = "ubuntu"
    bastion_host = "${module.network.bastion_public_ip}"
    bastion_user = "core"
  }

  # https://docs.openstack.org/project-deploy-guide/openstack-ansible/latest/run-playbooks.html#checking-the-integrity-of-the-configuration-files
  # https://docs.openstack.org/project-deploy-guide/openstack-ansible/latest/run-playbooks.html#run-the-playbooks-to-install-openstack
  provisioner "remote-exec" {
    inline = [
      "(cd /opt/openstack-ansible/playbooks && sudo openstack-ansible setup-openstack.yml --syntax-check)",
      "(cd /opt/openstack-ansible/playbooks && sudo openstack-ansible setup-openstack.yml)",
    ]
  }
}
