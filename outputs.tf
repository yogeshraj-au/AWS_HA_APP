#Output the fqdn of bastion servers
output "bastion_server_names" {
  value = [for i in aws_instance.bastion_server.*.id : element([for tag in aws_instance.bastion_server.*.tags : tag.Name if tag.Name != null], index(aws_instance.bastion_server.*.id, i))]
}

#output the URL of the backend app
output "backend_dns_name" {
  value = "The backend can be accessed at http://${aws_route53_record.backend_record.name}"
}