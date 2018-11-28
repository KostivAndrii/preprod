#Set-PSDebug -Trace 2

$RGN                  = $env:appResourceGroup
$location            = "West Europe"
$SubNet_Name  = "subnet01"
$AdPrSN             = '10.0.0.0/24'
$AdPrVN             = '10.0.0.0/16'
$AGWVnet          = 'appgwvnet'
$publicIP            = 'publicIP01'
$gatewayIP         = 'gatewayIP01'
$appGWBackendPool  = "appGWBEPool"
$webappprobe            = 'appProbe'
$appGWBackendHTTP= 'appGWBEHttpSettings'
$GWN                 = 'WAAppGW'

# Unique web app name
$wa1=$env:webapp1
$wa2=$env:webapp2
$wa1SP=$wa1 + 'SP'
$wa2SP=$wa2 + 'SP'

$rg = Get-AzureRmResourceGroup -Name $RGN -ErrorAction Ignore
if ( ! $rg ) {
  $rg = New-AzureRmResourceGroup -Name $RGN -Location $location
}

if ( ! $(Get-AzureRmAppServicePlan -ResourceGroupName $RGN -Name $wa1SP -ErrorAction Ignore)) {
  New-AzureRmAppServicePlan -Name $wa1SP -ResourceGroupName $RGN -Location $location -Tier Free
}
if ( ! $(Get-AzureRmAppServicePlan -ResourceGroupName $RGN -Name $wa2SP -ErrorAction Ignore)) {
  New-AzureRmAppServicePlan -Name $wa2SP -ResourceGroupName $RGN -Location $location -Tier Free
}

$webapp1 = Get-AzureRmWebApp -ResourceGroupName $RGN -Name $wa1 -ErrorAction Ignore
if( ! $webapp1 ) {
  $webapp1 = New-AzureRmWebApp -ResourceGroupName $RGN -Name $wa1 -Location $location -AppServicePlan $wa1SP
}

$webapp2 = Get-AzureRmWebApp -ResourceGroupName $RGN -Name $wa2 -ErrorAction Ignore
if( ! $webapp2 ) {
  $webapp2 = New-AzureRmWebApp -ResourceGroupName $RGN -Name $wa2 -Location $location -AppServicePlan $wa2SP
}

#$webapp2 = Get-AzureRmWebApp -ResourceGroupName $RGN -Name $wa2 -ErrorAction Ignore
#if( ! $webapp2 ) {
# $webapp2 = New-AzureRmWebApp -ResourceGroupName $RGN -Name $wa2 -Location $location -AppServicePlan $wa2SP
#}

$subnet = New-AzureRmVirtualNetworkSubnetConfig -Name $SubNet_Name -AddressPrefix $AdPrSN

$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $RGN -Name $AGWVnet -ErrorAction Ignore
if( ! $vnet ) {
  $vnet = New-AzureRmVirtualNetwork -Name $AGWVnet -ResourceGroupName $RGN -Location $location -AddressPrefix $AdPrVN -Subnet $subnet
}

$subnet=$vnet.Subnets[0]

$pip = Get-AzureRmPublicIpAddress -ResourceGroupName $RGN -Name $publicIP -ErrorAction Ignore
if( ! $pip ) {
       $pip = New-AzureRmPublicIpAddress -ResourceGroupName $RGN -Location $location  -Name $publicIP -AllocationMethod Dynamic
}

$gipconfig = New-AzureRmApplicationGatewayIPConfiguration -Name $gatewayIP -Subnet $subnet

$pool = New-AzureRmApplicationGatewayBackendAddressPool -Name $appGWBackendPool -BackendFqdns $webapp1.HostNames, $webapp2.HostNames

# Define the status codes to match for the probe
$match = New-AzureRmApplicationGatewayProbeHealthResponseMatch -StatusCode 200-399

# Create a probe with the PickHostNameFromBackendHttpSettings switch for web apps
$probeconfig = New-AzureRmApplicationGatewayProbeConfig -name $webappprobe  -Protocol Http -Path / -Interval 30 -Timeout 120 -UnhealthyThreshold 3 -PickHostNameFromBackendHttpSettings -Match $match

# Define the backend http settings
$poolSetting = New-AzureRmApplicationGatewayBackendHttpSettings -Name $appGWBackendHTTP -Port 80 -Protocol Http -CookieBasedAffinity Disabled -RequestTimeout 120 -PickHostNameFromBackendAddress -Probe $probeconfig

# Create a new front-end port
$fp = New-AzureRmApplicationGatewayFrontendPort -Name frontendport01  -Port 80

# Create a new front end IP configuration
$fipconfig = New-AzureRmApplicationGatewayFrontendIPConfig -Name fipconfig01 -PublicIPAddress $pip

# Create a new listener using the front-end ip configuration and port created earlier
$listener = New-AzureRmApplicationGatewayHttpListener -Name listener01 -Protocol Http -FrontendIPConfiguration $fipconfig -FrontendPort $fp

# Create a new rule
$rule = New-AzureRmApplicationGatewayRequestRoutingRule -Name rule01 -RuleType Basic -BackendHttpSettings $poolSetting -HttpListener $listener -BackendAddressPool $pool

# Define the application gateway SKU to use
$sku = New-AzureRmApplicationGatewaySku -Name Standard_Small -Tier Standard -Capacity 2

$appgw = Get-AzureRmApplicationGateway -ResourceGroupName $RGN -Name $GWN -ErrorAction Ignore
if( !  $appgw ) {
$appgw = New-AzureRmApplicationGateway -Name $GWN -ResourceGroupName $RGN -Location $location -BackendAddressPools $pool -BackendHttpSettingsCollection $poolSetting -Probes $probeconfig -FrontendIpConfigurations $fipconfig  -GatewayIpConfigurations $gipconfig -FrontendPorts $fp -HttpListeners $listener -RequestRoutingRules $rule -Sku $sku
}