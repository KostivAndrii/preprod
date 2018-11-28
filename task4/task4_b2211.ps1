# determine dir where should be var.ps1 and provision script
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent 

# loading variables
$vars_file = $scriptDir + '\vars.ps1'
if(![System.IO.File]::Exists($vars_file)){
  Write-Host "Absent var script in  $vars_file " -ForegroundColor DarkYellow
  exit 1
}
#. $scriptDir\vars.ps1

$resourceGroup       = "RG01"
$location            = "West Europe"
$SubNet_Name         = "subnet01"
$AddressPrefixSN     = '10.0.0.0/24'
$AddressPrefixVN     = '10.0.0.0/16'
$AGWVnet             = 'appgwvnet'
$publicIP            = 'publicIP01'
$gatewayIP           = 'gatewayIP01'
$appGWBackendPool    = "appGatewayBackendPool"
$webappprobe         = 'webappprobe'
$appGWBackendHTTP    = 'appGatewayBackendHttpSettings'

# Defines a variable for a dotnet get started web app repository location
$gitrepo1="https://github.com/Azure-Samples/app-service-web-dotnet-get-started.git"
$gitrepo2="https://github.com/KostivAndrii/StudentsList.git"

# Unique web app name
$webappname1="StudentList$(Get-Random)"
$webappname2="StudentList$(Get-Random)"

# Creates a resource group
$rg = New-AzureRmResourceGroup -Name $resourceGroup -Location $location

# Create an App Service plan in Free tier.
New-AzureRmAppServicePlan -Name $webappname1'SP' -Location $location -ResourceGroupName $rg.ResourceGroupName -Tier Free
New-AzureRmAppServicePlan -Name $webappname2'SP' -Location $location -ResourceGroupName $rg.ResourceGroupName -Tier Free

# Creates a web app
$webapp1 = New-AzureRmWebApp -ResourceGroupName $rg.ResourceGroupName -Name $webappname1 -Location $location -AppServicePlan $webappname1'SP'
$webapp2 = New-AzureRmWebApp -ResourceGroupName $rg.ResourceGroupName -Name $webappname2 -Location $location -AppServicePlan $webappname2'SP'

# Configure GitHub deployment from your GitHub repo and deploy once to web app.
$PropertiesObject1 = @{
    repoUrl = "$gitrepo1";
    branch = "master";
    isManualIntegration = "true";
}
Set-AzureRmResource -PropertyObject $PropertiesObject1 -ResourceGroupName $rg.ResourceGroupName -ResourceType Microsoft.Web/sites/sourcecontrols -ResourceName $webappname1/web -ApiVersion 2015-08-01 -Force
$PropertiesObject2 = @{
  repoUrl = "$gitrepo2";
  branch = "master";
  isManualIntegration = "true";
}
Set-AzureRmResource -PropertyObject $PropertiesObject2 -ResourceGroupName $rg.ResourceGroupName -ResourceType Microsoft.Web/sites/sourcecontrols -ResourceName $webappname2/web -ApiVersion 2015-08-01 -Force

# Creates a subnet for the application gateway
$subnet = New-AzureRmVirtualNetworkSubnetConfig -Name $SubNet_Name -AddressPrefix $AddressPrefixSN

# Creates a vnet for the application gateway
$vnet = New-AzureRmVirtualNetwork -Name $AGWVnet -ResourceGroupName $rg.ResourceGroupName -Location $location -AddressPrefix $AddressPrefixVN -Subnet $subnet

# Retrieve the subnet object for use later
$subnet=$vnet.Subnets[0]

# Create a public IP address
$publicip = New-AzureRmPublicIpAddress -ResourceGroupName $rg.ResourceGroupName -name $publicIP -location $location -AllocationMethod Dynamic

# Create a new IP configuration
$gipconfig = New-AzureRmApplicationGatewayIPConfiguration -Name $gatewayIP -Subnet $subnet

# Create a backend pool with the hostname of the web app
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
$fipconfig = New-AzureRmApplicationGatewayFrontendIPConfig -Name fipconfig01 -PublicIPAddress $publicip

# Create a new listener using the front-end ip configuration and port created earlier
$listener = New-AzureRmApplicationGatewayHttpListener -Name listener01 -Protocol Http -FrontendIPConfiguration $fipconfig -FrontendPort $fp

# Create a new rule
$rule = New-AzureRmApplicationGatewayRequestRoutingRule -Name rule01 -RuleType Basic -BackendHttpSettings $poolSetting -HttpListener $listener -BackendAddressPool $pool

# Define the application gateway SKU to use
$sku = New-AzureRmApplicationGatewaySku -Name Standard_Small -Tier Standard -Capacity 2

# Create the application gateway
$appgw = New-AzureRmApplicationGateway -Name ContosoAppGateway -ResourceGroupName $rg.ResourceGroupName -Location $location -BackendAddressPools $pool -BackendHttpSettingsCollection $poolSetting -Probes $probeconfig -FrontendIpConfigurations $fipconfig  -GatewayIpConfigurations $gipconfig -FrontendPorts $fp -HttpListeners $listener -RequestRoutingRules $rule -Sku $sku