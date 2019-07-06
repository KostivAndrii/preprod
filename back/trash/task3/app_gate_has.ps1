# Create a resource group
# General setting
$resourceGroup = "akostivRG01"
$location = "West Europe"
$StorageTypeManaged = "Standard_LRS"
$StorageTypeUnmanaged = "Standard_LRS"
$VMSize = 'Standard_D1'

$VNet = $resourceGroup + "_VNet"
$PublicIPAddressName = $resourceGroup + "_PublicIPAddress"
$AvailabilitySet = $resourceGroup + "_AvailabilitySet"
$VMnames = $resourceGroup + "_VM"
$BackendSubnet = $resourceGroup + "_BackendSubnet"

# windows VM init setting
$WPublisherName = 'MicrosoftWindowsServer' 
$WOffer = 'WindowsServer' 
$WSkus = '2016-Datacenter' 
$WVersion = 'latest'

$rdpPort = 3389
$httpPort = 8080

# user setting for login 
$UserName = 'azureuser'
$Passwd = 'PaSw0rD$'

$Password = ConvertTo-SecureString $Passwd -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($UserName, $Password)


New-AzureRmResourceGroup -Name $resourceGroup -Location $location

# Create network resources
$backendSubnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name $BackendSubnet -AddressPrefix 10.0.1.0/24
$agSubnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name myAGSubnet -AddressPrefix 10.0.2.0/24
$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Location $location `
  -Name $VNet -AddressPrefix 10.0.0.0/16 -Subnet $backendSubnetConfig, $agSubnetConfig
$pip = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location `
  -Name myAGPublicIPAddress -AllocationMethod Dynamic

# Create IP configurations and frontend port
$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Name $VNet
$subnet=$vnet.Subnets[0]
$gipconfig = New-AzureRmApplicationGatewayIPConfiguration -Name myAGIPConfig -Subnet $subnet
$fipconfig = New-AzureRmApplicationGatewayFrontendIPConfig -Name myAGFrontendIPConfig -PublicIPAddress $pip
$frontendport = New-AzureRmApplicationGatewayFrontendPort -Name myFrontendPort -Port 80

# Create the backend pool and settings
$defaultPool = New-AzureRmApplicationGatewayBackendAddressPool -Name appGatewayBackendPool 
$poolSettings = New-AzureRmApplicationGatewayBackendHttpSettings -Name myPoolSettings `
  -Port 80 -Protocol Http -CookieBasedAffinity Enabled -RequestTimeout 120

# Create the default listener and rule
$defaultlistener = New-AzureRmApplicationGatewayHttpListener -Name mydefaultListener -Protocol Http `
  -FrontendIPConfiguration $fipconfig -FrontendPort $frontendport
$frontendRule = New-AzureRmApplicationGatewayRequestRoutingRule -Name rule1 -RuleType Basic `
  -HttpListener $defaultlistener -BackendAddressPool $defaultPool -BackendHttpSettings $poolSettings
echo 0
# Create the application gateway
$sku = New-AzureRmApplicationGatewaySku -Name WAF_Medium -Tier WAF -Capacity 2
$appgw = New-AzureRmApplicationGateway -Name myAppGateway -ResourceGroupName $resourceGroup `
  -Location $location -BackendAddressPools $defaultPool -BackendHttpSettingsCollection $poolSettings `
  -FrontendIpConfigurations $fipconfig -GatewayIpConfigurations $gipconfig -FrontendPorts $frontendport `
  -HttpListeners $defaultlistener -RequestRoutingRules $frontendRule -Sku $sku 
echo 1


# Create a virtual machine avialability set

New-AzureRmAvailabilitySet -Location $location -Name $AvailabilitySet -ResourceGroupName $resourceGroup  `
   -Sku aligned -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 2

$nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig -Name Rule_RDP  -Protocol Tcp `
  -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
  -DestinationPortRange $rdpPort -Access Allow
$nsgRuleHTTP = New-AzureRmNetworkSecurityRuleConfig -Name Rule_HTTP  -Protocol Tcp `
  -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
  -DestinationPortRange $httpPort -Access Allow

$nsg = Get-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Name NSG_HAS -ErrorAction Ignore
if( ! $nsg ) {
    $nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location `
        -Name NSG_HAS -SecurityRules $nsgRuleHTTP, $nsgRuleRDP
}

for ($i=1; $i -le 2; $i++)
{
    New-AzureRmVm `
        -ResourceGroupName $resourceGroup `
        -Name $VMnames$i `
        -Location $location `
        -VirtualNetworkName $VNet `
        -SubnetName $BackendSubnet `
        -SecurityGroupName "myNetworkSecurityGroup" `
        -PublicIpAddressName "myPublicIpAddress$i" `
        -AvailabilitySetName $AvailabilitySet `
        -Credential $cred

$pip$i = Get-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Name $resourceGroup$W_prefix$PIP -ErrorAction Ignore
if( ! $pip$i ) {
    $pip$i = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location `
        -Name $resourceGroup$W_prefix$PIP -AllocationMethod Static -IdleTimeoutInMinutes 4
}

echo 'Windows public IP VM with managed DISK:'
$pip$i | Select-Object -Property IpAddress


$nic$i = Get-AzureRmNetworkInterface -Name $resourceGroup$NIC$i -ResourceGroupName $resourceGroup -ErrorAction Ignore
if( ! $nic$i ) {
    $nic$i = New-AzureRmNetworkInterface -Name $resourceGroup$NIC$i -ResourceGroupName $resourceGroup -Location $location `
      -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip$i.Id -NetworkSecurityGroupId $nsg.Id
}

$vmCfg$i = New-AzureRmVMConfig -VMName $resourceGroup -VMSize $VMSize | `
Set-AzureRmVMOperatingSystem -Windows -ComputerName $VMnames$i -Credential $cred | `
Set-AzureRmVMSourceImage -PublisherName $WPublisherName -Offer $WOffer -Skus $WSkus -Version $WVersion | `
Add-AzureRmVMNetworkInterface -Id $nic$i.Id

if( ! $(Get-AzureRMVM -ResourceGroupName $resourceGroup -Name $VMnames$i -ErrorAction Ignore) ) {
    New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vmCfg$i
}

}

# Create a virtual machine scale set
$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Name $VNet
echo 2
$appgw = Get-AzureRmApplicationGateway -ResourceGroupName $resourceGroup -Name myAppGateway
echo 3
$backendPool = Get-AzureRmApplicationGatewayBackendAddressPool -Name appGatewayBackendPool `
  -ApplicationGateway $appgw
echo 4


$vmssConfig = New-AzureRmVmssConfig -Location $location -SkuCapacity 2 -SkuName Standard_DS1_v2 `
  -UpgradePolicyMode Automatic
echo 6
Set-AzureRmVmssStorageProfile $vmssConfig -ImageReferencePublisher MicrosoftWindowsServer `
  -ImageReferenceOffer WindowsServer -ImageReferenceSku 2016-Datacenter -ImageReferenceVersion latest
echo 7
Set-AzureRmVmssOsProfile $vmssConfig -AdminUsername azureuser -AdminPassword "Azure123456!" `
  -ComputerNamePrefix myvmss
echo 8

$ipConfig = New-AzureRmVmssIpConfig -Name myVmssIPConfig -SubnetId $vnet.Subnets[1].Id `
  -ApplicationGatewayBackendAddressPoolsId $backendPool.Id
echo 5
Add-AzureRmVmssNetworkInterfaceConfiguration -VirtualMachineScaleSet $vmssConfig -Name myVmssNetConfig `
  -Primary $true -IPConfiguration $ipConfig
echo 9
New-AzureRmVmss -ResourceGroupName $resourceGroup -Name myvmss -VirtualMachineScaleSet $vmssConfig


# Install IIS
$publicSettings = @{ "fileUris" = (,"https://raw.githubusercontent.com/davidmu1/samplescripts/master/appgatewayurl.ps1"); 
  "commandToExecute" = "powershell -ExecutionPolicy Unrestricted -File appgatewayurl.ps1" }

$vmss = Get-AzureRmVmss -ResourceGroupName $resourceGroup -VMScaleSetName myvmss
Add-AzureRmVmssExtension -VirtualMachineScaleSet $vmss -Name "customScript" -Publisher "Microsoft.Compute" `
  -Type "CustomScriptExtension" -TypeHandlerVersion 1.8 -Setting $publicSettings
Update-AzureRmVmss -ResourceGroupName $resourceGroup -Name myvmss -VirtualMachineScaleSet $vmss

# Get the IP address
Get-AzureRmPublicIPAddress -ResourceGroupName $resourceGroup -Name myAGPublicIPAddress