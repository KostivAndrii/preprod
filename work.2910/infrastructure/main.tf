# terraform apply -var-file=var_values.tfvars

resource "azurerm_resource_group" "wikijs_rg" {
  name 					= "${var.resource_group_name}"
  location 				= "${var.location}"
}

resource "azurerm_virtual_network" "vnet" {
  name 					= "Wikijs-VNet"
  address_space 			= ["${var.vnet_cidr}"]
  location 				= "${var.location}"
  resource_group_name 			= "${azurerm_resource_group.wikijs_rg.name}"
  
  tags = {
	group 				= "Wiki.JS"
  }
}

resource "azurerm_subnet" "subnet" {
  name 					= "Wikijs-Subnet"
  address_prefix 			= "${var.subnet_cidr}"
  virtual_network_name 			= "${azurerm_virtual_network.vnet.name}"
  resource_group_name 			= "${azurerm_resource_group.wikijs_rg.name}"
}

resource "azurerm_network_security_group" "nsg_web" {
  name 					= "Wikijs-Web-NSG"
  location 				= "${var.location}"
  resource_group_name 			= "${azurerm_resource_group.wikijs_rg.name}"

  security_rule {
	name 				= "AllowSSH"
	priority 			= 100
	direction 			= "Inbound"
	access 				= "Allow"
	protocol 			= "Tcp"
	source_port_range          	= "*"
	destination_port_range     	= "22"
	source_address_prefix      	= "*"
	destination_address_prefix 	= "*"
  }

  security_rule {
	name 				= "AllowHTTP"
	priority			= 200
	direction			= "Inbound"
	access 				= "Allow"
	protocol 			= "Tcp"
	source_port_range          	= "*"
	destination_port_range     	= "80"
	source_address_prefix      	= "Internet"
	destination_address_prefix 	= "*"
  }

  tags = {
	group 				= "Wiki.JS"
  }
}

resource "azurerm_network_security_group" "wikijs_nsg_db" {
  name 					= "Wikijs-DB-NSG"
  location 				= "${var.location}"
  resource_group_name 			= "${azurerm_resource_group.wikijs_rg.name}"

  /*security_rule {
	name 						= "BlockInternet"
	priority 					= 100
	direction 					= "Outbound"
	access 						= "Deny"
	protocol 					= "Tcp"
	source_port_range          	= "*"
    destination_port_range     	= "*"
    source_address_prefix      	= "*"
    destination_address_prefix 	= "Internet"
  }*/

  security_rule {
	name 				= "AllowSSH"
	priority 			= 100
	direction 			= "Inbound"
	access 				= "Allow"
	protocol 			= "Tcp"
	source_port_range          	= "*"
	destination_port_range     	= "22"
	source_address_prefix      	= "*"
	destination_address_prefix 	= "*"
  }

  security_rule {
	name 				= "AllowMongoDB"
	priority			= 200
	direction			= "Inbound"
	access 				= "Allow"
	protocol 			= "Tcp"
	source_port_range          	= "*"
	destination_port_range     	= "27017"
	source_address_prefix      	= "${var.subnet_cidr}"
	destination_address_prefix 	= "*"
  }

  tags = {
	group 				= "Wiki.JS"
  }
}

resource "azurerm_storage_account" "storage" {
  name 					        = "wikijsstorage5432"
  resource_group_name 			= "${azurerm_resource_group.wikijs_rg.name}"
  location 				        = "${var.location}"
  account_tier             		= "Standard"
  account_replication_type 		= "GRS"

  
  tags = {
	group 				= "Wiki.JS"
  }
}

resource "azurerm_storage_container" "cont" {
  name 					= "wikivhds"
  resource_group_name 			= "${azurerm_resource_group.wikijs_rg.name}"
  storage_account_name 			= "${azurerm_storage_account.storage.name}"
  container_access_type 		= "private"
}

resource "azurerm_public_ip" "pip" {
  name 					        = "Wikijs-PIP"
  location 				        = "${var.location}"
  resource_group_name 			= "${azurerm_resource_group.wikijs_rg.name}"
  allocation_method 		    = "Static"


  provisioner "local-exec" {
    command = "echo [WEB_SERVER] >> hosts && echo ubuntuweb   ansible_host=${self.ip_address} >> hosts"
  }

  tags = {
	group 				        = "Wiki.JS"
  }
}

resource "azurerm_network_interface" "public_nic" {
  name 		      			= "Wikijs-Web"
  location 	      			= "${var.location}"
  resource_group_name 			= "${azurerm_resource_group.wikijs_rg.name}"
  network_security_group_id 		= "${azurerm_network_security_group.nsg_web.id}"

  ip_configuration {
    name 				= "Wikijs-WebPrivate"
    subnet_id 				= "${azurerm_subnet.subnet.id}"
    private_ip_address_allocation 	= "Dynamic"
    public_ip_address_id		= "${azurerm_public_ip.pip.id}"
  }
  tags = {
	group 				= "Wiki.JS"
  }
}

resource "azurerm_public_ip" "db_pip" {
  name                  		= "Wikijs-DB-PIP"
  location              		= "${var.location}"
  resource_group_name   		= "${azurerm_resource_group.wikijs_rg.name}"
  allocation_method      		= "Static"


  provisioner "local-exec" {
    command = "echo [DB_SERVER] >> hosts && echo ubuntudb   ansible_host=${self.ip_address} >> hosts"
  }

  tags = {
        group 				= "Wiki.JS"
  }
}

resource "azurerm_network_interface" "private_nic" {
  name 					            = "Wikijs-DB"
  location 				            = "${var.location}"
  resource_group_name 			    = "${azurerm_resource_group.wikijs_rg.name}"
  network_security_group_id 		= "${azurerm_network_security_group.wikijs_nsg_db.id}"

  ip_configuration {
    name 				            = "Wikijs-DBPrivate"
    subnet_id 				        = "${azurerm_subnet.subnet.id}"
    private_ip_address_allocation 	= "Static"
    private_ip_address 			    = "${var.DataBase_IP}"
    public_ip_address_id 		    = "${azurerm_public_ip.db_pip.id}"
  }
  tags = {
	group 				= "Wiki.JS"
  }
}

resource "azurerm_dns_zone" "dns" {
  name 					        = "yourdomain.com"
  resource_group_name   		= "${azurerm_resource_group.wikijs_rg.name}"
}

resource "azurerm_dns_a_record" "a" {
  name 					        = "A_Record"
  zone_name 				    = "${azurerm_dns_zone.dns.name}"
  resource_group_name   		= "${azurerm_resource_group.wikijs_rg.name}"
  ttl 					        = 300
  records 				        = ["${azurerm_public_ip.pip.ip_address}"]
}

resource "azurerm_virtual_machine" "web" {
  name                  		= "Wikijs-WebVM"
  location              		= "${var.location}"
  resource_group_name   		= "${azurerm_resource_group.wikijs_rg.name}"
  network_interface_ids 		= ["${azurerm_network_interface.public_nic.id}"]
  vm_size               		= "Standard_DS1_v2"

#This will delete the OS disk and data disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher 				= "Canonical"
    offer     				= "UbuntuServer"
    sku       				= "16.04-LTS"
    version   				= "latest"
  }

  storage_os_disk {
    name          			= "osdisk-1"
    vhd_uri       			= "${azurerm_storage_account.storage.primary_blob_endpoint}${azurerm_storage_container.cont.name}/osdisk-1.vhd"
    caching       			= "ReadWrite"
    create_option 			= "FromImage"
  }

  os_profile {
    computer_name  			= "ubuntuweb"
    admin_username 			= "${var.vm_username}"
    admin_password 			= "${var.vm_password}"
  }

  os_profile_linux_config {
    disable_password_authentication 	= true
    ssh_keys {
        path     			= "/home/wikijs/.ssh/authorized_keys"
        key_data 			= "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCEu9muQWd5Y0Wu+kmz/ImNFUeW5SLJyJgS5O4ADPmtdIcRf17znEpbWATkx15l+zugU2qB/fZR97t6NWAdbEcG7wAv0zFEht261JM/WhJ9kuOwAT1XSsiIJebRTTZ07+KW0dhgepr+eFnem7mZmtnV/m24x0tuxCj6o3F2fgPfuM5gp8gAQ+NVukz6mDP3jTDhjVOKl0kXAO2TyTc3uHizcE/U1Adc76Qifdssb8zmi5n5Y6bkxW8Nu2+TmFTX/XsDSEzo2cvN7eTOSh/zKq+sNO5jBdYFOR+8tMW61PW3uRWy1uyOCMI6/NGl+5RoXAfAqav/qSfrTLqjf6xm/YUL imported-openssh-key"
      }
  }

  tags = {
    group 				= "Wiki.JS"
  }
}

resource "azurerm_virtual_machine" "db" {
  name                  		= "Mongodb-DBVM"
  location              		= "${var.location}"
  resource_group_name   		= "${azurerm_resource_group.wikijs_rg.name}"
  network_interface_ids 		= ["${azurerm_network_interface.private_nic.id}"]
  vm_size               		= "Standard_DS1_v2"

#This will delete the OS disk and data disk automatically when deleting the VM
  delete_os_disk_on_termination = true
  #delete_data_disks_on_termination = true

  storage_image_reference {
    publisher 				= "Canonical"
    offer     				= "UbuntuServer"
    sku       				= "16.04-LTS"
    version   				= "latest"
  }

  storage_os_disk {
    name          			= "osdisk-2"
    vhd_uri       			= "${azurerm_storage_account.storage.primary_blob_endpoint}${azurerm_storage_container.cont.name}/osdisk-2.vhd"
    caching       			= "ReadWrite"
    create_option 			= "FromImage"
  }

  # Optional data disks
  storage_data_disk {
    name          			= "datadisk-2"
    vhd_uri       			= "${azurerm_storage_account.storage.primary_blob_endpoint}${azurerm_storage_container.cont.name}/datadisk-2.vhd"
    disk_size_gb  			= "100"
    create_option 			= "Empty"
    lun           			= 0
  }

  os_profile {
    computer_name  			= "ubuntudb"
    admin_username 			= "${var.vm_username}"
    admin_password 			= "${var.vm_password}"
  }

  os_profile_linux_config {
    disable_password_authentication 	= true
    ssh_keys {
        path     			= "/home/wikijs/.ssh/authorized_keys"
        key_data 			= "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCEu9muQWd5Y0Wu+kmz/ImNFUeW5SLJyJgS5O4ADPmtdIcRf17znEpbWATkx15l+zugU2qB/fZR97t6NWAdbEcG7wAv0zFEht261JM/WhJ9kuOwAT1XSsiIJebRTTZ07+KW0dhgepr+eFnem7mZmtnV/m24x0tuxCj6o3F2fgPfuM5gp8gAQ+NVukz6mDP3jTDhjVOKl0kXAO2TyTc3uHizcE/U1Adc76Qifdssb8zmi5n5Y6bkxW8Nu2+TmFTX/XsDSEzo2cvN7eTOSh/zKq+sNO5jBdYFOR+8tMW61PW3uRWy1uyOCMI6/NGl+5RoXAfAqav/qSfrTLqjf6xm/YUL imported-openssh-key"
      }
  }

  tags = {
    group 				= "Wiki.JS"
  }
}

