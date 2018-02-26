provider "openstack" {
  user_name   = "${var.username}"
  password    = "${var.password}"
  tenant_name = "${var.tenant_name}"
  domain_name = "${var.domain_name}"
  auth_url    = "${var.endpoint}"
}

## Definir el nombre del VPC y las interfaces
data "openstack_networking_network_v2" "extnet" {
  name = "${var.external_network}"
}

resource "openstack_networking_router_v2" "router" {
  name             = "${var.project}-VPC"
  admin_state_up   = "true"
  external_network_id = "${data.openstack_networking_network_v2.extnet.id}"
  enable_snat      = "true"

}

resource "openstack_networking_router_interface_v2" "interface" {
  router_id = "${openstack_networking_router_v2.router.id}"
  subnet_id = "${openstack_networking_subnet_v2.subnet.id}"
}


resource "openstack_networking_network_v2" "terraform_test" {
  name           = "terraform_test"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "subnet" {
  name       = "subnet_1"
  network_id = "${openstack_networking_network_v2.terraform_test.id}"
  cidr       = "192.168.199.0/24"
}

resource "openstack_compute_instance_v2" "webserver" {
  count           = "${var.instance_count}"
  name            = "${var.project}-webserver${format("%02d", count.index+1)}"
  image_name      = "${var.image_name}"
  flavor_name     = "${var.flavor_name}"
  key_pair        = "${var.existent_keypair}"
  network {
    port = "${element(openstack_networking_port_v2.network_port.*.id, count.index)}"
    access_network = true
  }
  depends_on       = ["openstack_networking_router_interface_v2.interface"]
}

resource "openstack_networking_port_v2" "network_port" {
  count              = "${var.instance_count}"
  network_id         = "${openstack_networking_network_v2.terraform_test.id}"
  security_group_ids = [
    "${openstack_compute_secgroup_v2.secgrp_web.id}"
  ]
  admin_state_up     = "true"
  fixed_ip           = {
    subnet_id        = "${openstack_networking_subnet_v2.subnet.id}"
  }
}

## Security groups
resource "openstack_compute_secgroup_v2" "secgrp_web" {
  name        = "${var.project}-secgrp-web"
  description = "Webserver Security Group"

  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 80
    to_port     = 80
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = -1
    to_port     = -1
    ip_protocol = "icmp"
    cidr        = "0.0.0.0/0"
  }
}

# Keypair de acceso a las instancias
#resource "openstack_compute_keypair_v2" "keypair" {
#  name       = "${var.project}-terraform_key"
#  ##Esto hace referencia a la keypair ya existente en la cuenta, si se quisiera crear una nueva, 
#  public_key = "${file("${var.ssh_pub_key}")}"
#}
