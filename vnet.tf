# Azure
provider "azurerm" {
}

# Resource group
resource "azurerm_resource_group" "rg" {
  name = "${var.customer}-rg"
  location = "${var.region}"
}

# Virtual network
resource "azurerm_virtual_network" "vnet" {
  name = "${var.customer}-vnet"
  address_space = ["${var.vnet_cidr}"]
  location = "${var.region}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

# Route table for the public subnet (via the Internet)
resource "azurerm_route_table" "public_rtb" {
  name = "${var.customer}-publicrtb"
  location = "${var.region}"
  route {
    name = "publicroute"
    address_prefix = "*"
    next_hop_type = "Internet"
  }
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

# Public subnet
resource "azurerm_subnet" "pubsub" {
  name = "${var.customer}-${var.pubsub_name}-subnet"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  address_prefix = "${var.pubsub_cidr}"
  route_table_id = "${azurerm_route_table.public_rtb.id}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

# NAT box
# Security groups
resource "azurerm_network_security_group" "nat_sg_public_ssh" {
  name = "${var.customer}-nat-sg-public-ssh"
  location = "${var.region}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
}
resource "azurerm_network_security_group" "nat_sg_private_ssh" {
  name = "${var.customer}-nat-sg-private-ssh"
  location = "${var.region}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

# SSH access to public VMs from Eduserv
resource "azurerm_network_security_rule" "nat_nsr_public_ssh_eduserv" {
  name = "${var.customer}-nat-sg-ssh-eduserv-access-rule"
  network_security_group_name = "${azurerm_network_security_group.nat_sg_public_ssh.name}"
  direction = "Inbound"
  access = "Allow"
  priority = 200
  source_address_prefix = "188.92.143.3/32"
  source_port_range = "*"
  destination_address_prefix = "${var.pubsub_cidr}"
  destination_port_range = "22"
  protocol = "Tcp"
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

# SSH access to public VMs from APHome
resource "azurerm_network_security_rule" "nat_nsr_public_ssh_aphome" {
  name = "${var.customer}-nat-sg-ssh-aphome-access-rule"
  network_security_group_name = "${azurerm_network_security_group.nat_sg_public_ssh.name}"
  direction = "Inbound"
  access = "Allow"
  priority = 201
  source_address_prefix = "86.133.215.118/32"
  source_port_range = "*"
  destination_address_prefix = "${var.pubsub_cidr}"
  destination_port_range = "22"
  protocol = "Tcp"
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

# SSH access to private VMs from public VMs
resource "azurerm_network_security_rule" "nat_nsr_private_ssh_access" {
  count = "${var.prisub_count}"
  name = "${var.customer}-nat-sg-private_ssh-access-rule"
  network_security_group_name = "${azurerm_network_security_group.nat_sg_private_ssh.name}"
  direction = "Inbound"
  access = "Allow"
  priority = 200
  source_address_prefix = "${var.pubsub_cidr}"
  source_port_range = "*"
  destination_address_prefix = "${lookup(var.prisub_cidrs, count.index)}"
  destination_port_range = "22"
  protocol = "Tcp"
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

# Public IP address
resource "azurerm_public_ip" "nat_ip" {
  name = "${var.customer}-nat-public-ip"
  location = "${var.region}"
  public_ip_address_allocation = "dynamic"
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

# Network interface
resource "azurerm_network_interface" "nat_ni" {
  name = "${var.customer}-nat-ni"
  location = "${var.region}"
  network_security_group_id = "${azurerm_network_security_group.nat_sg_public_ssh.id}"
  ip_configuration {
    name = "${var.customer}-nat-ni-config"
    subnet_id = "${azurerm_subnet.pubsub.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id = "${azurerm_public_ip.nat_ip.id}"
  }
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

# Random Id
resource "random_id" "nat_sa_id" {
  byte_length = 4
  keepers = {
    # Generate a new id each time we switch to a new version
    storage_account_version = "${var.storage_account_version}"
  }
}

# Storage account
resource "azurerm_storage_account" "nat_sa" {
  name = "natsa${random_id.nat_sa_id.hex}v${var.storage_account_version}"
  location = "${var.region}"
  account_type = "Standard_LRS"
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

# Storage container
resource "azurerm_storage_container" "nat_sc" {
  name = "${var.customer}-nat-sc"
  storage_account_name = "${azurerm_storage_account.nat_sa.name}"
  container_access_type = "private"
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

# Random password
resource "random_id" "password" {
  byte_length = 4
  keepers = {
    # Generate a new id each time we switch to a new customer
    customer = "${var.customer}"
  }
}

# NAT VM
resource "azurerm_virtual_machine" "nat" {
  name = "${var.customer}-nat"
  location = "${var.region}"
  network_interface_ids = ["${azurerm_network_interface.nat_ni.id}"]
  vm_size = "Standard_A0"
  storage_image_reference {
    publisher = "Canonical"
    offer = "UbuntuServer"
    sku = "14.04.2-LTS"
    version = "latest"
  }
  storage_os_disk {
    name = "${var.customer}-nat-os-disk"
    vhd_uri = "${azurerm_storage_account.nat_sa.primary_blob_endpoint}${azurerm_storage_container.nat_sc.name}/nat-os-disk.vhd"
    caching = "ReadWrite"
    create_option = "FromImage"
  }
#  storage_data_disk {
#    name = "${var.customer}-nat-data-disk"
#    vhd_uri = "${azurerm_storage_account.nat_sa.primary_blob_endpoint}${azurerm_storage_container.nat_sc.name}/nat-data-disk.vhd"
#    disk_size_gb = "20"
#    create_option = "empty"
#    lun = 0
#  }
  os_profile {
    computer_name = "${var.customer}-nat"
    admin_username = "ubuntu"
    admin_password = "UP-lo${random_id.password.hex}!"
  }
  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys = {
      path = "/home/ubuntu/.ssh/authorized_keys"
      key_data = "${file(var.public_key_path)}"
    }
  }
  tags {
    Power = "dev"
    Owner = "andy.powell@eduserv.org.uk"
    Billing = "ap.eduservlab.net"
  }
#  # The connection block tells our provisioner how to
#  # communicate with the resource (instance)
#  connection {
#    # The default username for our AMI
#    user = "ubuntu"
#    type = "ssh"
#    private_key = "${file(var.private_key_path)}"
#    host = "${azurerm_public_ip.nat_ip.ip_address}"
#    # The connection will use the local SSH agent for authentication.
#  }
#  provisioner "remote-exec" {
#    inline = [
#      "sudo apt-get -y update",
#      "sudo apt-get -y upgrade",
#      "echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf",
#      "sysctl -w net.ipv4.ip_forward=1"
#    ]
#  }
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

# VM extension to set up the NAT server
resource "azurerm_virtual_machine_extension" "nat_ext" {
  name = "${var.customer}-nat-ext"
  location = "${var.region}"
  virtual_machine_name = "${azurerm_virtual_machine.nat.name}"
  publisher = "Microsoft.OSTCExtensions"
  type = "CustomScriptForLinux"
  type_handler_version = "1.2"
#  "commandToExecute": "echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf && sysctl -w net.ipv4.ip_forward=1 && touch /tmp/ipforwarding"
  settings = <<EOF
{
  "fileUris": [
    "https://raw.githubusercontent.com/andypowe11/Azure-Terraform-Basic-VNet/master/configure_ip_forwarding.sh"
  ],
  "commandToExecute": "bash configure_ip_forwarding.sh"
}
EOF
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

# Route table for the private subnet (via the NAT box)
resource "azurerm_route_table" "private_rtb" {
  name = "${var.customer}-privatertb"
  location = "${var.region}"
  route {
    name = "privateroute"
    address_prefix = "*"
    next_hop_type = "VirtualAppliance"
    next_hop_in_ip_address = "${azurerm_network_interface.nat_ni.private_ip_address}"
  }
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

# Up to three private subnets
resource "azurerm_subnet" "prisub" {
  count = "${var.prisub_count}"
  name = "${var.customer}-${lookup(var.prisub_names, count.index)}-subnet"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  address_prefix = "${lookup(var.prisub_cidrs, count.index)}"
  route_table_id = "${azurerm_route_table.private_rtb.id}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
}
