# Create a resource group
# General setting
$resourceGroup             = "RG01"
$location                  = "West Europe"
$VMSize                    = 'Standard_DS1_v2'
$VMnames                   = $resourceGroup + "VM"
 
$VNet_Name                 = $resourceGroup + "_VNet"
$VNet_Address              = '10.0.0.0/16'
$SubNet_Name               = $resourceGroup + "_Subnet"
$SubNet_Address            = '10.0.1.0/24'
$BackendSubnet_Name        = $resourceGroup + "_Backend"
$BackendSubnet_Address     = '10.0.2.0/24'

#$NSG_Rule_RDP              = 'NSG_Rule_RDP'
#$NSG_RDP                   = 'NSG_RDP'
$PublicIPAddressName       = $resourceGroup + "_PublicIPAddress"
$AvailabilitySet_name      = $resourceGroup + "_AvailabilitySet"
$NIC_name                  = $resourceGroup + "_NIC"
$GWIPConfig                = "IPConfig"
$FeIPConfig                = "FrontendIPConfig"
$FePort                    = 80
$FePort_name               = "FrontendPort"
$BePool_name               = "BackendPool"
$PoolSetting_name          = "PoolSettings"
$BackendPoolPort           = 8080
$Listener_name             = "Listener"
$Protocol                  = "Http"
$AppGateway                = $resourceGroup + "AppGateway"
$RequestTime               = 30
# windows VM init setting
$WPublisherName            = 'MicrosoftWindowsServer' 
$WOffer                    = 'WindowsServer' 
$WSkus                     = '2016-Datacenter' 
$WVersion                  = 'latest'
#$rdpPort = 3389

# user setting for login 
$UserName = 'azureuser'
$Passwd = 'Pa$$w0rd'

$Password = ConvertTo-SecureString $Passwd -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($UserName, $Password)


if ( ! $(Get-AzureRmResourceGroup -Name $resourceGroup -ErrorAction Ignore)) {
            New-AzureRmResourceGroup -Name $resourceGroup -Location $location
}


# Create network resources

$SubnetConfig= New-AzureRmVirtualNetworkSubnetConfig -Name $SubNet_Name -AddressPrefix $SubNet_Address
$backendSubnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name $BackendSubnet_Name -AddressPrefix $BackendSubnet_Address

$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Name $VNet_Name -ErrorAction Ignore
if( ! $vnet ) {
    $vnet = New-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Location $location -Name $VNet_Name -AddressPrefix $VNet_Address  `
      -Subnet $SubnetConfig, $backendSubnetConfig
}

$pip = Get-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Name $PublicIPAddressName -ErrorAction Ignore
if( ! $pip ) {
       $pip = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location  `
            -Name $PublicIPAddressName -AllocationMethod Dynamic
}

#$nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig -Name $resourceGroup$NSG_Rule_RDP  -Protocol Tcp `
#  -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
#  -DestinationPortRange $rdpPort, 8080, 80 -Access Allow


#$nsgRDP = Get-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Name $resourceGroup$NSG_RDP -ErrorAction Ignore
#if( ! $nsgRDP ) {
#    $nsgRDP = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location `
#        -Name $resourceGroup$NSG_RDP -SecurityRules $nsgRuleRDP
#}

  # Create backend servers

#Get-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Name $VNet_Name

$AvailabilitySet = Get-AzureRmAvailabilitySet -ResourceGroupName $resourceGroup -Name $AvailabilitySet_name -ErrorAction Ignore
if( ! $AvailabilitySet ) {
    $AvailabilitySet = New-AzureRmAvailabilitySet -Location $location -Name $AvailabilitySet_name -ResourceGroupName $resourceGroup  `
       -Sku aligned -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 2
}

for ($i=1; $i -le 2; $i++)
{

#  $pip_b = Get-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Name $PublicIPAddressName$i -ErrorAction Ignore
#    if( ! $pip_b ) {
#           $pip_b = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location  `
#                -Name $PublicIPAddressName$i -AllocationMethod Dynamic
#    }
  
  $nic = Get-AzureRmNetworkInterface -Name $NIC_name$i -ResourceGroupName $resourceGroup -ErrorAction Ignore 
  if( ! $nic ) {
      $nic = New-AzureRmNetworkInterface -Name $NIC_name$i -ResourceGroupName $resourceGroup -Location $location  `
        -SubnetId $vnet.Subnets[1].Id 
#        -SubnetId $vnet.Subnets[1].Id -PublicIpAddressId $pip_b.Id -NetworkSecurityGroupId $nsgRDP.Id
  }

  $vm = New-AzureRmVMConfig -VMName $VMnames$i -VMSize $VMSize -AvailabilitySetID $AvailabilitySet.Id
  $vm = Set-AzureRmVMOperatingSystem -VM $vm -Windows -ComputerName $VMnames$i -Credential $cred
  $vm = Set-AzureRmVMSourceImage -VM $vm -PublisherName $WPublisherName -Offer $WOffer -Skus $WSkus -Version $WVersion
  $vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id
  $vm = Set-AzureRmVMBootDiagnostics -VM $vm -Disable
  
  
  if( ! $(Get-AzureRMVM -ResourceGroupName $resourceGroup -Name $VMnames$i -ErrorAction Ignore) ) {
    New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vm
    Set-AzureRmVMExtension -ResourceGroupName $resourceGroup -ExtensionName IIS -VMName $VMnames$i -Location $location `
       -Publisher Microsoft.Compute -ExtensionType CustomScriptExtension -TypeHandlerVersion 1.4 `
       -SettingString '{"commandToExecute":"powershell Add-WindowsFeature Web-Server; powershell Add-Content -Path \"C:\\inetpub\\wwwroot\\Default.htm\" -Value $($env:computername)"}' 
     Invoke-AzureRmVMRunCommand -ResourceGroupName $resourceGroup -Name $VMnames$i -CommandId 'RunPowerShellScript' `
       -ScriptPath '.\Documents\preprod\task3\customiis.ps1' -Parameter @{"arg1" = $i}
  }  
}

# Create an application gateway

# Create the IP configurations and frontend port

$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Name $VNet_Name
$pip = Get-AzureRmPublicIPAddress -ResourceGroupName $resourceGroup -Name $PublicIPAddressName 
$subnet=$vnet.Subnets[0]
$gipconfig = New-AzureRmApplicationGatewayIPConfiguration -Name $GWIPConfig -Subnet $subnet
$fipconfig = New-AzureRmApplicationGatewayFrontendIPConfig -Name $FeIPConfig -PublicIPAddress $pip
$frontendport = New-AzureRmApplicationGatewayFrontendPort -Name $FePort_name -Port $FePort

# Create the backend pool


$address1 = Get-AzureRmNetworkInterface -ResourceGroupName $resourceGroup -Name $NIC_name'1'
$address2 = Get-AzureRmNetworkInterface -ResourceGroupName $resourceGroup -Name $NIC_name'2'
$backendPool = New-AzureRmApplicationGatewayBackendAddressPool -Name $BePool_name `
  -BackendIPAddresses $address1.ipconfigurations[0].privateipaddress, $address2.ipconfigurations[0].privateipaddress
$poolSettings = New-AzureRmApplicationGatewayBackendHttpSettings `
  -Name $PoolSetting_name -Port $BackendPoolPort -Protocol $Protocol -CookieBasedAffinity Enabled -RequestTimeout $RequestTime

#Create the listener and add a rule

$defaultlistener = New-AzureRmApplicationGatewayHttpListener -Name $Listener_name `
  -Protocol $Protocol -FrontendIPConfiguration $fipconfig -FrontendPort $frontendport
$frontendRule = New-AzureRmApplicationGatewayRequestRoutingRule -Name rule1 -RuleType Basic -HttpListener $defaultlistener `
  -BackendAddressPool $backendPool -BackendHttpSettings $poolSettings

#Create the application gateway

$sku = New-AzureRmApplicationGatewaySku -Name Standard_Medium -Tier Standard -Capacity 2


if( ! $(Get-AzureRmApplicationGateway -ResourceGroupName $resourceGroup -Name $AppGateway -ErrorAction Ignore) ) {
    New-AzureRmApplicationGateway -Name $AppGateway `
      -ResourceGroupName $resourceGroup `
      -Location $location `
      -BackendAddressPools $backendPool `
      -BackendHttpSettingsCollection $poolSettings `
      -FrontendIpConfigurations $fipconfig `
      -GatewayIpConfigurations $gipconfig `
      -FrontendPorts $frontendport `
      -HttpListeners $defaultlistener `
      -RequestRoutingRules $frontendRule `
      -Sku $sku
}
  
  
#  #Invoke-AzureRmVMRunCommand -ResourceGroupName $resourceGroup -Name $VMnames'1' `
#    -CommandId 'RunPowerShellScript' -ScriptPath 'customiis.ps1' `
#    -Parameter @{"arg1" = "1";"arg2" = "var2"}
#  Invoke-AzureRmVMRunCommand -ResourceGroupName $resourceGroup -Name $VMnames'2' `
#    -CommandId 'RunPowerShellScript' -ScriptPath 'customiis.ps1' `
#    -Parameter @{"arg1" = "2";"arg2" = "var2"}
  # Get-AzureRmPublicIPAddress -ResourceGroupName $resourceGroup -Name $PublicIPAddressName