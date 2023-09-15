#Output the ami-id
output "ami-id" {
  value = data.aws_ami.ubuntu_server.id
}