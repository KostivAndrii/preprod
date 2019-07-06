$resourceGroup             = "RG01"
$location                  = "West Europe"
$VMSize                    = 'Standard_DS1_v2'
$VMnames                   = $resourceGroup + "VM"
$VM_provision_script_name  = 'customiis.ps1'

$VNet_Name                 = $resourceGroup + "_VNet"
$VNet_Address              = '10.0.0.0/16'
$SubNet_Name               = $resourceGroup + "_Subnet"
$SubNet_Address            = '10.0.1.0/24'
$BackendSubnet_Name        = $resourceGroup + "_Backend"
$BackendSubnet_Address     = '10.0.2.0/24'
$PublicIPAddressName       = $resourceGroup + "_PublicIPAddress"
$AvailabilitySet_name      = $resourceGroup + "_AvailabilitySet"
$NIC_name                  = $resourceGroup + "_NIC"

$GWIPConfig                = "IPConfig"
$FrontendIPConfig          = "FrontendIPConfig"
$FrontendPort              = 80
$FrontendPort_name         = "FrontendPort"
$BackendPool_name          = "BackendPool"
$BackendPoolPort           = 8080
$PoolSetting_name          = "PoolSettings"
$Listener_name             = "Listener"
$Protocol                  = "Http"
$AppGateway                = $resourceGroup + "AppGateway"
$AG_sku_name               = "Standard_Medium"
$AG_Tier_name              = "Standard"
# AG probe setiing
$probe_name                = "probe01"
$RequestTime               = 10
$IntervalTime              = 5
$UnhealthyThreshold        = 2
# windows VM init setting
$WPublisherName            = 'MicrosoftWindowsServer' 
$WOffer                    = 'WindowsServer' 
$WSkus                     = '2016-Datacenter' 
$WVersion                  = 'latest'

# user setting for login 
$UserName = 'azureuser'
$Passwd = 'Pa$$w0rd'
