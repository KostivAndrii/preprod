$resourceGroup             = "RG02"
$location                  = "West Europe"
$VMSize                    = 'Standard_DS1_v2'
$VMnames                   = $resourceGroup + "VM"
$VM_provision_script_name  = 'customiis.ps1'
$ManDataDiskNameW          = $resourceGroup + "MAN_DATADISK"

$VNet_Name                 = $resourceGroup + "_VNet"
$VNet_Address              = '10.0.0.0/16'
$SubNet_Name               = $resourceGroup + "_Subnet"
$SubNet_Address            = '10.0.1.0/24'
#$BackendSubnet_Name        = $resourceGroup + "_Backend"
#$BackendSubnet_Address     = '10.0.2.0/24'
$PublicIPAddress_Name      = $resourceGroup + "_PublicIPAddress"
$AvailabilitySet_name      = $resourceGroup + "_AvailabilitySet"
$NIC_name                  = $resourceGroup + "_NIC"
$StorageTypeManaged = "Standard_LRS"
$OSDiskSize = 30
$DataDiskSize = 10

#$GWIPConfig                = "IPConfig"
$FrontendIPConfig          = "FrontendIPConfig"

#$FrontendPort_name         = "FrontendPort"
$BackendPool_name          = "BackendPool"
$FrontendPortWeb              = 80
$BackendPortWeb               = 8080
$FrontendPortRDP1              = 4221
$FrontendPortRDP2              = 4222
$BackendPortRDP               = 3389
#$PoolSetting_name          = "PoolSettings"
#$Listener_name             = "Listener"
$LoadBalancer_Name         = $resourceGroup + "LB"
$LoadBalancerRuleWeb       = 'myLoadBalancerRuleWeb'
$LoadBalancerRuleRDP       = 'myLoadBalancerRDP'
#$AG_sku_name               = "Standard_Medium"
#$AG_Tier_name              = "Standard"
# AG probe setiing
$probe_name                = "probe01"
$ProbeProtocol             = "Http"
$ProbePort                 = 80
#$RequestTime               = 10
$IntervalTime              = 5
$ProbeCount        = 2
# windows VM init setting
$WPublisherName            = 'MicrosoftWindowsServer' 
$WOffer                    = 'WindowsServer' 
$WSkus                     = '2016-Datacenter' 
$WVersion                  = 'latest'

# user setting for login 
$UserName = 'azureuser'
$Passwd = 'Pa$$w0rd'

#other
$ProvisionApsent = $false