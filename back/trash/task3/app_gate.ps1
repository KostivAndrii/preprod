# Create a resource group


New-AzureRmResourceGroup -Name myResourceGroupAG1 -Location westeurope`

# Create network resources
$backendSubnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name myBackendSubnet -AddressPrefix 10.0.1.0/24
$agSubnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name myAGSubnet -AddressPrefix 10.0.2.0/24
$vnet = New-AzureRmVirtualNetwork -ResourceGroupName myResourceGroupAG1 -Location westeurope `
  -Name myVNet -AddressPrefix 10.0.0.0/16 -Subnet $backendSubnetConfig, $agSubnetConfig
$pip = New-AzureRmPublicIpAddress -ResourceGroupName myResourceGroupAG1 -Location westeurope `
  -Name myAGPublicIPAddress -AllocationMethod Dynamic

# Create IP configurations and frontend port
$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName myResourceGroupAG1 -Name myVNet
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
$appgw = New-AzureRmApplicationGateway -Name myAppGateway -ResourceGroupName myResourceGroupAG1 `
  -Location westeurope -BackendAddressPools $defaultPool -BackendHttpSettingsCollection $poolSettings `
  -FrontendIpConfigurations $fipconfig -GatewayIpConfigurations $gipconfig -FrontendPorts $frontendport `
  -HttpListeners $defaultlistener -RequestRoutingRules $frontendRule -Sku $sku 
echo 1
# Create a virtual machine scale set
$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName myResourceGroupAG1 -Name myVNet
echo 2
$appgw = Get-AzureRmApplicationGateway -ResourceGroupName myResourceGroupAG1 -Name myAppGateway
echo 3
$backendPool = Get-AzureRmApplicationGatewayBackendAddressPool -Name appGatewayBackendPool `
  -ApplicationGateway $appgw
echo 4
$ipConfig = New-AzureRmVmssIpConfig -Name myVmssIPConfig -SubnetId $vnet.Subnets[1].Id `
  -ApplicationGatewayBackendAddressPoolsId $backendPool.Id
echo 5
$vmssConfig = New-AzureRmVmssConfig -Location westeurope -SkuCapacity 2 -SkuName Standard_DS1_v2 `
  -UpgradePolicyMode Automatic
echo 6
Set-AzureRmVmssStorageProfile $vmssConfig -ImageReferencePublisher MicrosoftWindowsServer `
  -ImageReferenceOffer WindowsServer -ImageReferenceSku 2016-Datacenter -ImageReferenceVersion latest
echo 7
Set-AzureRmVmssOsProfile $vmssConfig -AdminUsername azureuser -AdminPassword "Azure123456!" `
  -ComputerNamePrefix myvmss
echo 8
Add-AzureRmVmssNetworkInterfaceConfiguration -VirtualMachineScaleSet $vmssConfig -Name myVmssNetConfig `
  -Primary $true -IPConfiguration $ipConfig
echo 9
New-AzureRmVmss -ResourceGroupName myResourceGroupAG1 -Name myvmss -VirtualMachineScaleSet $vmssConfig

# Install IIS
$publicSettings = @{ "fileUris" = (,"https://raw.githubusercontent.com/davidmu1/samplescripts/master/appgatewayurl.ps1"); 
  "commandToExecute" = "powershell -ExecutionPolicy Unrestricted -File appgatewayurl.ps1" }

$vmss = Get-AzureRmVmss -ResourceGroupName myResourceGroupAG1 -VMScaleSetName myvmss
Add-AzureRmVmssExtension -VirtualMachineScaleSet $vmss -Name "customScript" -Publisher "Microsoft.Compute" `
  -Type "CustomScriptExtension" -TypeHandlerVersion 1.8 -Setting $publicSettings
Update-AzureRmVmss -ResourceGroupName myResourceGroupAG1 -Name myvmss -VirtualMachineScaleSet $vmss

# Get the IP address
Get-AzureRmPublicIPAddress -ResourceGroupName myResourceGroupAG1 -Name myAGPublicIPAddress