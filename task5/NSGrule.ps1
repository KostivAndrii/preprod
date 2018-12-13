        {
            "type": "Microsoft.Network/networkSecurityGroups/securityRules",
            "name": "[concat(variables('NSG_name'), '/', variables('NSGRuleHTTP_name'))]",
            "apiVersion": "2018-08-01",
            "properties": {
                "description": "Allow HTTP",
                "protocol": "Tcp",
                "sourcePortRange": "*",
                "destinationPortRange": "[variables('backend_Port')]",
                "sourceAddressPrefix": "Internet",
                "destinationAddressPrefix": "*",
                "access": "Allow",
                "priority": 1000,
                "direction": "Inbound"
            },
            "dependsOn": [
                "[resourceId('Microsoft.Network/networkSecurityGroups', variables('NSG_name'))]"
            ]
        },

        {
            "type": "Microsoft.Network/virtualNetworks/subnets",
            "name": "[concat(variables('VNet_name'), '/', variables('Subnet_name'))]",
            "apiVersion": "2018-08-01",
            "properties": {
                "addressPrefix": "[variables('subnetPrefix')]"
            },
            "dependsOn": [
                "[resourceId('Microsoft.Network/virtualNetworks', variables('VNet_name'))]"
            ]
        },


        "addressPrefix": "10.0.0.0/16", 
        "subnetPrefix": "10.0.1.0/24", 
        "vmSize": "Standard_DS1_v2",
        "publisher": "MicrosoftWindowsServer",
        "offer": "WindowsServer",
        "sku": "2016-Datacenter",
        "version": "latest",
        "storageAccountType": "Standard_LRS",
        "probe_protocol": "Http",
        "probe_intervalInSeconds": 5,
        "probe_numberOfProbes": 2,
        "Username": "azureuser",
        "Password": "Pa$$w0rd",
        "frontend_Port": 80,
        "backend_Port": 8080
