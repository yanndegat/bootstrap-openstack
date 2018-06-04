---
# This file contains data that controls the post-deployment configuration
# of OpenStack by the Ansible playbook openstack-service-setup.yml

# Define a set of VM flavors to be created
vm_flavors:
  - name: m1.micro
    ram: 512
    vcpus: 1
    disk: 1
    swap: 0
    ephemeral: 0
  - name: m1.small
    ram: 1024
    vcpus: 1
    disk: 5
    swap: 0
    ephemeral: 4
  - name: m1.medium
    ram: 2048
    vcpus: 2
    disk: 5
    swap: 0
    ephemeral: 4

# Create shared networks and subnets:
provider_net_name: ${provider_net_name}
provider_net_cidr: ${provider_net_cidr}
provider_dns_server: "${provider_dns_server}"
provider_subnet_name: "{{ provider_net_name }}_SUBNET"

private_net_name: PRIVATE_NET
private_net_cidr: 192.168.0.0/24
private_subnet_name: "{{ private_net_name }}_SUBNET"

networks:
  - name: "{{ provider_net_name }}"
    shared: true
    external: true
    network_type: flat
    physical_network: flat
  - name: "{{ private_net_name }}"
    shared: true
    external: true
    network_type: vxlan
    segmentation_id: 101

subnets:
  - name: "{{ provider_subnet_name }}"
    network_name: "{{ provider_net_name }}"
    ip_version: 4
    cidr: "{{ provider_net_cidr }}"
    gateway_ip: "${provider_subnet_gw}"
    enable_dhcp: "${provider_subnet_enable_dhcp}"
    allocation_pool_start: "${provider_subnet_pool_start}"
    allocation_pool_end:   "${provider_subnet_pool_end}"
    dns_nameservers:
       - "{{ provider_dns_server }}"
  - name: "{{ private_subnet_name }}"
    network_name: "{{ private_net_name }}"
    ip_version: 4
    cidr: "{{ private_net_cidr }}"
    gateway_ip: "{{ private_net_cidr | ipaddr('1') | ipaddr('address') }}"
    enable_dhcp: true
    allocation_pool_start: "{{ private_net_cidr | ipaddr('10') | ipaddr('address') }}"
    allocation_pool_end:   "{{ private_net_cidr | ipaddr('254') | ipaddr('address') }}"

router_name: GATEWAY_NET_ROUTER
security_group_name: gateway_security
port_name: gateway_port

# Neutron security group setup
security_group_rules: []

# Create some default images
images:
  - name: Ubuntu 16.04
    format: qcow2
    url: http://uec-images.ubuntu.com/releases/16.04/release/ubuntu-16.04-server-cloudimg-amd64-disk1.img
  - name: Cirros-0.3.5
    format: qcow2
    url: http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img
