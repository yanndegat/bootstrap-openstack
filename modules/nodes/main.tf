data "template_file" "systemd_network_files" {
  count = "${var.count}"

  template = <<TPL
# ssh if
- path: /etc/systemd/network/10-ens3.network
  permissions: '0644'
  content: |
    [Match]
    Name=ens3
    [Network]
    DHCP=ipv4

- path: /etc/systemd/network/20-ens4.network
  permissions: '0644'
  content: |
    [Match]
    Name=ens4
    [Network]
    DHCP=no
    Bridge=br-mgmt
- path: /etc/systemd/network/20-br-mgmt.netdev
  permissions: '0644'
  content: |
    [NetDev]
    Name=br-mgmt
    Kind=bridge
- path: /etc/systemd/network/20-br-mgmt.network
  permissions: '0644'
  content: |
    [Match]
    Name=br-mgmt
    [Network]
    DHCP=no
    Address=${element(flatten(openstack_networking_port_v2.mgmt.*.all_fixed_ips), count.index)}
    [Route]
    Gateway=${var.internet_gw}
    Destination=0.0.0.0/0
    [Route]
    GatewayOnlink=yes
    Destination=${var.cidr}

# vxlan if
- path: /etc/systemd/network/30-ens5.network
  permissions: '0644'
  content: |
    [Match]
    Name=ens5
    [Network]
    DHCP=no
    Bridge=br-vxlan
- path: /etc/systemd/network/30-br-vxlan.netdev
  permissions: '0644'
  content: |
    [NetDev]
    Name=br-vxlan
    Kind=bridge
- path: /etc/systemd/network/30-br-vxlan.network
  permissions: '0644'
  content: |
    [Match]
    Name=br-vxlan
    [Network]
    DHCP=no
    Address=${element(flatten(openstack_networking_port_v2.vxlan.*.all_fixed_ips), count.index)}
    [Route]
    GatewayOnlink=yes
    Destination=${var.cidr}

# vlan if
- path: /etc/systemd/network/40-ens6.network
  permissions: '0644'
  content: |
    [Match]
    Name=ens6
    [Network]
    DHCP=no
    Bridge=br-vlan
- path: /etc/systemd/network/40-br-vlan.netdev
  permissions: '0644'
  content: |
    [NetDev]
    Name=br-vlan
    Kind=bridge

# storage if
- path: /etc/systemd/network/50-ens7.network
  permissions: '0644'
  content: |
    [Match]
    Name=ens7
    [Network]
    DHCP=no
    Bridge=br-storage
- path: /etc/systemd/network/50-br-storage.netdev
  permissions: '0644'
  content: |
    [NetDev]
    Name=br-storage
    Kind=bridge
- path: /etc/systemd/network/50-br-storage.network
  permissions: '0644'
  content: |
    [Match]
    Name=br-storage
    [Network]
    DHCP=no
    Address=${element(flatten(openstack_networking_port_v2.storage.*.all_fixed_ips), count.index)}
    [Route]
    GatewayOnlink=yes
    Destination=${var.cidr}

# external port if enabled
- path: /etc/systemd/network/50-ens8.network
  permissions: '0644'
  content: |
    [Match]
    Name=ens8
    [Network]
    DHCP=ipv4

TPL
}

# https://docs.openstack.org/project-deploy-guide/openstack-ansible/latest/targethosts.html#configuring-the-operating-system
data "template_file" "nodes" {
  count = "${var.count}"

  template = <<CLOUDCONFIG
#cloud-config
ntp:
  enabled: true
  ntp_client: chrony
packages:
    - bridge-utils
    - debootstrap
    - ifenslave
    - ifenslave-2.6
    - lsof
    - lvm2
    - ntp
    - ntpdate
    - openssh-server
    - sudo
    - tcpdump
    - vlan
    - python
package_update: true
package_upgrade: true
package_reboot_if_required: true
ssh_authorized_keys:
   - ${var.ansible_public_key}
disable_root: false
write_files:
  ${indent(2, data.template_file.systemd_network_files.*.rendered[count.index])}
  - path: /root/.ssh/id_rsa.pub
    permissions: '0600'
    content: |
        bonding
        8021q
  - path: /etc/systemd/system/dev-sdb.device
    permissions: '0644'
    content: |
        [Unit]
        Description=Asks for lvm setup if /dev/sdb device is present
        Wants=lvm-setup@sdb.service
        [Install]
        WantedBy=multi-user.target
  - path: /etc/systemd/system/lvm-setup@.service
    permissions: '0644'
    content: |
        [Unit]
        Description=Runs lvm setup on parameterized device name
        After=dev-%i.device
        Requires=dev-%i.device
        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStart=/bin/sh -c 'if ! pvs /dev/'%i' | grep -q /dev/'%i'; then pvcreate --metadatasize 2048 /dev/'%i'; fi'
        ExecStart=/bin/sh -c 'if ! pvs /dev/'%i' | grep -q /dev/'%i'.*${var.lvm_vg_name}; then vgcreate ${var.lvm_vg_name} /dev/'%i'; fi'
        [Install]
        WantedBy=multi-user.target
runcmd:
  - systemctl enable sdb.device
  - systemctl enable systemd-networkd.service
power_state:
    mode: reboot
CLOUDCONFIG
}

data "openstack_networking_network_v2" "ext_net" {
  name      = "Ext-Net"
  tenant_id = ""
}

resource "openstack_networking_port_v2" "ext_port" {
  count = "${var.with_external_port ? var.count: 0}"

  name               = "${var.name}_ext_${count.index}"
  network_id         = "${data.openstack_networking_network_v2.ext_net.id}"
  admin_state_up     = "true"
  security_group_ids = ["${var.security_group_ids}"]
}

resource "openstack_networking_port_v2" "ssh" {
  count          = "${var.count}"
  name           = "${var.name}_${count.index}_ssh"
  network_id     = "${var.network_id}"
  admin_state_up = "true"

  fixed_ip {
    subnet_id = "${var.ssh_subnet_id}"
  }
}

resource "openstack_networking_port_v2" "mgmt" {
  count          = "${var.count}"
  name           = "${var.name}_${count.index}_mgmt"
  network_id     = "${var.network_id}"
  admin_state_up = "true"

  fixed_ip {
    subnet_id = "${var.mgmt_subnet_id}"
  }
}

resource "openstack_networking_port_v2" "vxlan" {
  count          = "${var.count}"
  name           = "${var.name}_${count.index}_vxlan"
  network_id     = "${var.network_id}"
  admin_state_up = "true"

  fixed_ip {
    subnet_id = "${var.vxlan_subnet_id}"
  }
}

resource "openstack_networking_port_v2" "vlan" {
  count          = "${var.count}"
  name           = "${var.name}_${count.index}_vlan"
  network_id     = "${var.network_id}"
  admin_state_up = "true"

  fixed_ip {
    subnet_id = "${var.vlan_subnet_id}"
  }
}

resource "openstack_networking_port_v2" "storage" {
  count          = "${var.count}"
  name           = "${var.name}_${count.index}_storage"
  network_id     = "${var.network_id}"
  admin_state_up = "true"

  fixed_ip {
    subnet_id = "${var.storage_subnet_id}"
  }
}

resource "openstack_compute_instance_v2" "internal_nodes" {
  count       = "${var.with_external_port ? 0: var.count}"
  name        = "${var.name}_${count.index}"
  image_name  = "${var.image_name}"
  flavor_name = "${var.flavor_name}"
  key_pair    = "${var.key_pair}"
  user_data   = "${data.template_file.nodes.*.rendered[count.index]}"

  # order matters: see systemd network files
  network {
    access_network = true
    port           = "${openstack_networking_port_v2.ssh.*.id[count.index]}"
  }

  network {
    port = "${openstack_networking_port_v2.mgmt.*.id[count.index]}"
  }

  network {
    port = "${openstack_networking_port_v2.vxlan.*.id[count.index]}"
  }

  network {
    port = "${openstack_networking_port_v2.vlan.*.id[count.index]}"
  }

  network {
    port = "${openstack_networking_port_v2.storage.*.id[count.index]}"
  }
}

resource "openstack_compute_instance_v2" "external_nodes" {
  count       = "${var.with_external_port ? var.count: 0}"
  name        = "${var.name}_${count.index}"
  image_name  = "${var.image_name}"
  flavor_name = "${var.flavor_name}"
  key_pair    = "${var.key_pair}"
  user_data   = "${data.template_file.nodes.*.rendered[count.index]}"

  # order matters: see systemd network files
  network {
    access_network = true
    port           = "${openstack_networking_port_v2.ssh.*.id[count.index]}"
  }

  network {
    port = "${openstack_networking_port_v2.mgmt.*.id[count.index]}"
  }

  network {
    port = "${openstack_networking_port_v2.vxlan.*.id[count.index]}"
  }

  network {
    port = "${openstack_networking_port_v2.vlan.*.id[count.index]}"
  }

  network {
    port = "${openstack_networking_port_v2.storage.*.id[count.index]}"
  }

  network {
    port = "${openstack_networking_port_v2.ext_port.*.id[count.index]}"
  }
}

resource "openstack_blockstorage_volume_v2" "nodes" {
  count = "${var.additional_storage > 0 ? var.count : 0}"
  name  = "${var.name}_${count.index}"
  size  = "${var.additional_storage}"
}

resource "openstack_compute_volume_attach_v2" "nodes" {
  count       = "${var.additional_storage > 0 ? var.count : 0}"
  instance_id = "${element(concat(openstack_compute_instance_v2.external_nodes.*.id, openstack_compute_instance_v2.internal_nodes.*.id), count.index)}"
  volume_id   = "${openstack_blockstorage_volume_v2.nodes.*.id[count.index]}"
}

data "template_file" "ext_ipv4_addrs" {
  count    = "${var.with_external_port ? var.count: 0}"
  template = "${element(compact(split(",", replace(join(",", flatten(openstack_networking_port_v2.ext_port.*.all_fixed_ips)), "/[[:alnum:]]+:[^,]+/", ""))), count.index)}"
}
