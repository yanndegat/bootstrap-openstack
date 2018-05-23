# output "ext_ip_v4" {
#   value       = "${zipmap(concat(var.service_nodes,var.storage_nodes), data.template_file.ext_ipv4_addrs.*.rendered)}"
# }

output "deployer_access_ipv4" {
  value       = "${openstack_compute_instance_v2.deployer.access_ip_v4}"
}
