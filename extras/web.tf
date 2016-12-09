# Load balancer public IP address
resource "azurerm_public_ip" "lb_ip" {
  name = "${var.customer}-lb-public-ip"
  location = "${var.region}"
  public_ip_address_allocation = "static"
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

# Load balancer
resource "azurerm_lb" "lb" {
  name = "${var.customer}-lb"
  location = "${var.region}"
  frontend_ip_configuration {
    name = "${var.customer}-public-ip-conf"
    public_ip_address_id = "${azurerm_public_ip.lb_ip.id}"
  }
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

# Load balancer web probe
resource "azurerm_lb_probe" "web_probe" {
  name = "${var.customer}-web-probe"
  location = "${var.region}"
  loadbalancer_id = "${azurerm_lb.lb.id}"
  protocol = "Tcp"
  port = 80
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

# Load balancer web access rule
resource "azurerm_lb_rule" "web_access" {
  name = "${var.customer}-web-access"
  location = "${var.region}"
  loadbalancer_id = "${azurerm_lb.lb.id}"
  protocol = "Tcp"
  frontend_ip_configuration_name = "${var.customer}-public-ip-conf"
  frontend_port = 80
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.lb_bap.id}"
  backend_port = 80
  probe_id = "${azurerm_lb_probe.web_probe.id}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

# Load balancer backend address pool
resource "azurerm_lb_backend_address_pool" "lb_bap" {
#  name = "${var.customer}-lb-bap}"
# Terraform complains if this name has hyphens in it :-(
  name = "lbbap"
  location = "${var.region}"
  loadbalancer_id = "${azurerm_lb.lb.id}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

# Web network security group
resource "azurerm_network_security_group" "web_sg" {
  name = "${var.customer}-web-sg"
  location = "${var.region}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

# HTTP access to private VMs from public subnet
resource "azurerm_network_security_rule" "web_nsr_web_rule" {
#  count = "${var.prisub_count}"
#  name = "${var.customer}-web-sg-web-rule-${count.index}"
  name = "${var.customer}-web-sg-web-rule"
  network_security_group_name = "${azurerm_network_security_group.web_sg.name}"
  direction = "Inbound"
  access = "Allow"
#  priority = "${count.index + 200}"
  priority = 200
#  source_address_prefix = "${var.pubsub_cidr}"
#  source_address_prefix = "AzureLoadBalancer"
  source_address_prefix = "*"
  source_port_range = "*"
#  destination_address_prefix = "${lookup(var.prisub_cidrs, count.index)}"
  destination_address_prefix = "*"
  destination_port_range = "*"
#  protocol = "Tcp"
  protocol = "*"
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

# Web server network interface
resource "azurerm_network_interface" "web_ni" {
  name = "${var.customer}-web-ni"
  location = "${var.region}"
  network_security_group_id = "${azurerm_network_security_group.web_sg.id}"
  ip_configuration {
    name = "${var.customer}-web-ni-config"
    subnet_id = "${azurerm_subnet.prisub.0.id}"
    private_ip_address_allocation = "dynamic"
    load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.lb_bap.id}"]
#    load_balancer_inbound_nat_rules_ids = ["${azurerm_lb_nat_rule.web_access.id}"]
  }
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

# Web VM
resource "azurerm_virtual_machine" "web" {
  name = "${var.customer}-web"
  location = "${var.region}"
  network_interface_ids = ["${azurerm_network_interface.web_ni.id}"]
  vm_size = "Standard_A0"
  storage_image_reference {
    publisher = "Canonical"
    offer = "UbuntuServer"
    sku = "14.04.2-LTS"
    version = "latest"
  }
  storage_os_disk {
    name = "${var.customer}-web-os-disk"
    vhd_uri = "${azurerm_storage_account.nat_sa.primary_blob_endpoint}${azurerm_storage_container.nat_sc.name}/web-os-disk.vhd"
    caching = "ReadWrite"
    create_option = "FromImage"
  }
  os_profile {
    computer_name = "${var.customer}-web"
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
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

# VM extension to set up the NAT server
resource "azurerm_virtual_machine_extension" "web_ext" {
  name = "${var.customer}-web-ext"
  location = "${var.region}"
  virtual_machine_name = "${azurerm_virtual_machine.web.name}"
  publisher = "Microsoft.OSTCExtensions"
  type = "CustomScriptForLinux"
  type_handler_version = "1.2"
#  "commandToExecute": "echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf && sysctl -w net.ipv4.ip_forward=1 && touch /tmp/ipforwarding"
  settings = <<EOF
{
  "fileUris": [
    "https://raw.githubusercontent.com/andypowe11/Azure-Terraform-Basic-VNet/master/install-web.sh"
  ],
  "commandToExecute": "bash install-web.sh"
}
EOF
  resource_group_name = "${azurerm_resource_group.rg.name}"
}
