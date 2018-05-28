# output "ext_ip_v4" {
#   value       = "${zipmap(concat(var.service_nodes,var.storage_nodes), data.template_file.ext_ipv4_addrs.*.rendered)}"
# }

output "deployer_access_ipv4" {
  value = "${openstack_compute_instance_v2.deployer.access_ip_v4}"
}

output "haproxy_ext_ipv4" {
  value = "${element(coalescelist(module.haproxy_nodes.ext_ip_v4, module.haproxy_nodes.mgmt_ip_v4), 0)}"
}

output "helper" {
  value = <<HELPER
Your openstack infrastucture is up & running

you can access your horizon dashboard at the following address:

https://${element(coalescelist(module.haproxy_nodes.ext_ip_v4, module.haproxy_nodes.mgmt_ip_v4), 0)}

Enjoy!
HELPER
}
