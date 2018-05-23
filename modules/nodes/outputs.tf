output "names" {
  description = "node names"
  value = ["${concat(openstack_compute_instance_v2.internal_nodes.*.name, openstack_compute_instance_v2.external_nodes.*.name)}"]
}

output "ids" {
  description = "node ids"
  value = ["${concat(openstack_compute_instance_v2.internal_nodes.*.id, openstack_compute_instance_v2.external_nodes.*.id)}"]
}

output "access_ip_v4" {
  description = "nodes access ipv4"
  value = ["${concat(openstack_compute_instance_v2.internal_nodes.*.access_ip_v4, openstack_compute_instance_v2.external_nodes.*.access_ip_v4)}"]
}

output "mgmt_ip_v4" {
  description = "nodes mgmt ipv4"
  value = ["${flatten(openstack_networking_port_v2.mgmt.*.all_fixed_ips)}"]
}

output "ext_ip_v4" {
  description = "nodes ext ip v4"
  value = ["${data.template_file.ext_ipv4_addrs.*.rendered}"]
}
