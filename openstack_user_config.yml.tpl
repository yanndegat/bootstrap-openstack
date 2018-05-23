---
cidr_networks:
   container: ${cidr_network_container}
   tunnel: ${cidr_network_tunnel}
   storage: ${cidr_network_storage}

global_overrides:
  management_bridge: "br-mgmt"
  external_lb_vip_address: ${external_lb_vip_address}
  internal_lb_vip_address: ${internal_lb_vip_address}

  provider_networks:
    - network:
        group_binds:
          - all_containers
          - hosts
        type: "raw"
        container_bridge: "br-mgmt"
        container_interface: "eth1"
        container_type: "veth"
        ip_from_q: "container"
        is_container_address: true
        is_ssh_address: true
    - network:
        group_binds:
          - glance_api
          - cinder_api
          - cinder_volume
          - nova_compute
        type: "raw"
        container_bridge: "br-storage"
        container_type: "veth"
        container_interface: "eth2"
        container_mtu: "9000"
        ip_from_q: "storage"
    - network:
        group_binds:
          - neutron_linuxbridge_agent
        container_bridge: "br-vxlan"
        container_type: "veth"
        container_interface: "eth10"
        container_mtu: "9000"
        ip_from_q: "tunnel"
        type: "vxlan"
        range: "1:1000"
        net_name: "vxlan"
    - network:
        group_binds:
          - neutron_linuxbridge_agent
        container_bridge: "br-vlan"
        container_type: "veth"
        container_interface: "eth11"
        type: "vlan"
        range: "101:200,301:400"
        net_name: "vlan"
    - network:
        group_binds:
          - neutron_linuxbridge_agent
        container_bridge: "br-vlan"
        container_type: "veth"
        container_interface: "eth12"
        host_bind_override: "eth12"
        type: "flat"
        net_name: "flat"


shared-infra_hosts:
  ${shared_infra_hosts}

repo-infra_hosts:
  ${repo_infra_hosts}

os-infra_hosts:
  ${os_infra_hosts}

identity_hosts:
  ${identity_hosts}

network_hosts:
  ${network_hosts}

compute_hosts:
  ${compute_hosts}

storage_infra_hosts:
  ${storage_infra_hosts}

storage_hosts:
  ${storage_hosts}

haproxy_hosts:
  ${haproxy_hosts}
