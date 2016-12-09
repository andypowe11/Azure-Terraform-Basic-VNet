output "address" {
  value = "http://${azurerm_public_ip.lb_ip.ip_address}/"
}
