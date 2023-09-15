#Get the current region from the provider block
data "aws_region" "current" {}

#Get the list of Az's which is available in a region
data "aws_availability_zones" "available" {
  state = "available"
}

#Initialize the module to retrieve the ami-id
module "ami" {
  source = "./modules/amilookup"
}

#Create a route53 zone
resource "aws_route53_zone" "private" {
  name = var.domain_name
}

#Create a key pair to authenticate with ec2
resource "aws_key_pair" "server_ssh_key" {
  key_name   = "ssh_key"
  public_key = file("id_rsa.pub") #assuming the keys are already created
}

#Create a security group to allow ssh for bastion hosts
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Allow ssh inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "ssh from public"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks      = ["${var.bastion_cidr}"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion_sg"
  }
}

#Create bastion ec2 instances to connect with ec2 instances in private subnet. In each AZ, one bastion host will be created.
resource "aws_instance" "bastion_server" {
  count                       = var.bastion_instance_count
  ami                         = module.ami.ami-id
  instance_type               = var.bastion_server_instance_type
  availability_zone           = element(var.azs, count.index)
  subnet_id                   = module.vpc.public_subnets[count.index]
  key_name                    = aws_key_pair.server_ssh_key.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]

  root_block_device {
    volume_size = "10"
  }

  tags = {
    Name = "bastion-0${count.index + 1}-${element(var.azs, count.index)}.${var.domain_name}"
  }
}

#Create a Route53 record for the bastion hosts
resource "aws_route53_record" "bastion" {
  count = length(var.azs)

  name    = "bastion-0${count.index + 1}-${element(var.azs, count.index)}.${var.domain_name}"
  type    = "A"
  zone_id = aws_route53_zone.private.zone_id

  ttl = "300"

  records = [aws_instance.bastion_server[count.index].private_ip]
}
