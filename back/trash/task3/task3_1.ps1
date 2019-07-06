# Create a resource group
# General setting
$resourceGroup = "akostivRG03"
$location = "West Europe"
$VMSize = 'Standard_DS1_v2'
$VMnames = $resourceGroup + "VM"

$VNet_Name = $resourceGroup + "_VNet"
$PublicIPAddressName = $resourceGroup + "_PublicIPAddress"
$AvailabilitySet = $resourceGroup + "_AvailabilitySet"
$BackendSubnet = $resourceGroup + "_BackendSubnet"

# user setting for login 
$UserName = 'azureuser'
$Passwd = 'PaSw0rD$'

$Password = ConvertTo-SecureString $Passwd -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($UserName, $Password)


New-AzureRmResourceGroup -Name $resourceGroup -Location $location

# Create network resources

$backendSubnetConfig = New-AzureRmVirtualNetworkSubnetConfig `
  -Name myAGSubnet `
  -AddressPrefix 10.0.1.0/24
$agSubnetConfig = New-AzureRmVirtualNetworkSubnetConfig `
  -Name myBackendSubnet `
  -AddressPrefix 10.0.2.0/24
New-AzureRmVirtualNetwork `
  -ResourceGroupName $resourceGroup `
  -Location $location `
  -Name $VNet_Name `
  -AddressPrefix 10.0.0.0/16 `
  -Subnet $backendSubnetConfig, $agSubnetConfig
New-AzureRmPublicIpAddress `
  -ResourceGroupName $resourceGroup `
  -Location $location `
  -Name myAGPublicIPAddress `
  -AllocationMethod Dynamic

  # Create backend servers

$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Name $VNet_Name
#$cred = Get-Credential

$AvailabilitySet = New-AzureRmAvailabilitySet -Location $location -Name $AvailabilitySet -ResourceGroupName $resourceGroup  `
   -Sku aligned -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 2

for ($i=1; $i -le 2; $i++)
{
  $nic = New-AzureRmNetworkInterface `
    -Name myNic$i `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -SubnetId $vnet.Subnets[1].Id
  $vm = New-AzureRmVMConfig `
    -VMName $VMnames$i `
    -VMSize $VMSize `
    -AvailabilitySetID $AvailabilitySet.Id
  $vm = Set-AzureRmVMOperatingSystem `
    -VM $vm `
    -Windows `
    -ComputerName $VMnames$i `
    -Credential $cred
  $vm = Set-AzureRmVMSourceImage `
    -VM $vm `
    -PublisherName MicrosoftWindowsServer `
    -Offer WindowsServer `
    -Skus 2016-Datacenter `
    -Version latest
  $vm = Add-AzureRmVMNetworkInterface `
    -VM $vm `
    -Id $nic.Id
  $vm = Set-AzureRmVMBootDiagnostics `
    -VM $vm `
    -Disable
  New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vm
  # -AvailabilitySetName $AvailabilitySet

  Set-AzureRmVMExtension `
    -ResourceGroupName $resourceGroup `
    -ExtensionName IIS `
    -VMName $VMnames$i `
    -Publisher Microsoft.Compute `
    -ExtensionType CustomScriptExtension `
    -TypeHandlerVersion 1.4 `
    -SettingString '{"commandToExecute":"powershell Add-WindowsFeature Web-Server; powershell Add-Content -Path \"C:\\inetpub\\wwwroot\\Default.htm\" -Value $($env:computername)"}' `
    -Location $location
}

# Create an application gateway

# Create the IP configurations and frontend port

$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Name $VNet_Name
$pip = Get-AzureRmPublicIPAddress -ResourceGroupName $resourceGroup -Name myAGPublicIPAddress 
$subnet=$vnet.Subnets[0]
$gipconfig = New-AzureRmApplicationGatewayIPConfiguration `
  -Name myAGIPConfig `
  -Subnet $subnet
$fipconfig = New-AzureRmApplicationGatewayFrontendIPConfig `
  -Name myAGFrontendIPConfig `
  -PublicIPAddress $pip
$frontendport = New-AzureRmApplicationGatewayFrontendPort `
  -Name myFrontendPort `
  -Port 80

# Create the backend pool

$address1 = Get-AzureRmNetworkInterface -ResourceGroupName $resourceGroup -Name myNic1
$address2 = Get-AzureRmNetworkInterface -ResourceGroupName $resourceGroup -Name myNic2
$backendPool = New-AzureRmApplicationGatewayBackendAddressPool `
  -Name myAGBackendPool `
  -BackendIPAddresses $address1.ipconfigurations[0].privateipaddress, $address2.ipconfigurations[0].privateipaddress
$poolSettings = New-AzureRmApplicationGatewayBackendHttpSettings `
  -Name myPoolSettings `
  -Port 80 `
  -Protocol Http `
  -CookieBasedAffinity Enabled `
  -RequestTimeout 120

#Create the listener and add a rule

$defaultlistener = New-AzureRmApplicationGatewayHttpListener `
  -Name myAGListener `
  -Protocol Http `
  -FrontendIPConfiguration $fipconfig `
  -FrontendPort $frontendport
$frontendRule = New-AzureRmApplicationGatewayRequestRoutingRule `
  -Name rule1 `
  -RuleType Basic `
  -HttpListener $defaultlistener `
  -BackendAddressPool $backendPool `
  -BackendHttpSettings $poolSettings

#Create the application gateway

$sku = New-AzureRmApplicationGatewaySku `
  -Name Standard_Medium `
  -Tier Standard `
  -Capacity 2
New-AzureRmApplicationGateway `
  -Name myAppGateway `
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

  Get-AzureRmPublicIPAddress -ResourceGroupName $resourceGroup -Name myAGPublicIPAddress