output "public_ip_web" {
  description = "id of the public ip address provisoned."
  value       = "${azurerm_public_ip.pip.ip_address}"
}	

output "public_ip_db" {
  description = "id of the public ip address provisoned."
  value       = "${azurerm_public_ip.db_pip.ip_address}"
}

/*output "public_DB_ip_address" {
  description = "The actual ip address allocated for the resource."
  value       = "${azurerm_public_ip.db_pip.ip_address}"
}
*/
