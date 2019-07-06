# To decrease project starting time some job working in background
# VM and Application Gateway are created in background
# provision script wait when VM start to configure started VM
# 

# determine dir where should be var.ps1 and provision script
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent 

# loading variables
$vars_file = $scriptDir + '\vars.ps1'
if(![System.IO.File]::Exists($vars_file)){
  Write-Host "Absent var script in  $vars_file " -ForegroundColor DarkYellow
  exit 1
}
. $scriptDir\vars.ps1

# checking provision script
$provision_script = $scriptDir + '\' + $VM_provision_script_name
if(![System.IO.File]::Exists($provision_script)){
  Write-Host "Absent provision script in  $provision_script " -ForegroundColor DarkYellow
  $BackendPoolPort = 80
}

$a = Get-Date -UFormat %T
Write-Host "Starting to make project $resourceGroup at $a " -ForegroundColor DarkYellow

$Password = ConvertTo-SecureString $Passwd -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($UserName, $Password)


# Create a resource group

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


# Create backend servers

$AvailabilitySet = Get-AzureRmAvailabilitySet -ResourceGroupName $resourceGroup -Name $AvailabilitySet_name -ErrorAction Ignore
if( ! $AvailabilitySet ) {
    $AvailabilitySet = New-AzureRmAvailabilitySet -Location $location -Name $AvailabilitySet_name -ResourceGroupName $resourceGroup  `
       -Sku aligned -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 2
}

for ($i=1; $i -le 2; $i++)
{
  
  $nic = Get-AzureRmNetworkInterface -Name $NIC_name$i -ResourceGroupName $resourceGroup -ErrorAction Ignore 
  if( ! $nic ) {
      $nic = New-AzureRmNetworkInterface -Name $NIC_name$i -ResourceGroupName $resourceGroup -Location $location  `
        -SubnetId $vnet.Subnets[1].Id 
  }

  $vm = New-AzureRmVMConfig -VMName $VMnames$i -VMSize $VMSize -AvailabilitySetID $AvailabilitySet.Id
  $vm = Set-AzureRmVMOperatingSystem -VM $vm -Windows -ComputerName $VMnames$i -Credential $cred
  $vm = Set-AzureRmVMSourceImage -VM $vm -PublisherName $WPublisherName -Offer $WOffer -Skus $WSkus -Version $WVersion
  $vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id
  $vm = Set-AzureRmVMBootDiagnostics -VM $vm -Disable
  
  $a = Get-Date -UFormat %T
  Write-Host "Starting to build $VMnames$i at $a " -ForegroundColor DarkYellow
  
  if( ! $(Get-AzureRMVM -ResourceGroupName $resourceGroup -Name $VMnames$i -ErrorAction Ignore) ) {
    New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vm -AsJob
  }  
}


# Create an application gateway

# Create the IP configurations and frontend port

$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Name $VNet_Name
$pip = Get-AzureRmPublicIPAddress -ResourceGroupName $resourceGroup -Name $PublicIPAddressName 
$subnet=$vnet.Subnets[0]
$gipconfig = New-AzureRmApplicationGatewayIPConfiguration -Name $GWIPConfig -Subnet $subnet
$fipconfig = New-AzureRmApplicationGatewayFrontendIPConfig -Name $FrontendIPConfig -PublicIPAddress $pip
$frontendport = New-AzureRmApplicationGatewayFrontendPort -Name $FrontendPort_name -Port $FrontendPort


# Create the backend pool

$address1 = Get-AzureRmNetworkInterface -ResourceGroupName $resourceGroup -Name $NIC_name'1'
$address2 = Get-AzureRmNetworkInterface -ResourceGroupName $resourceGroup -Name $NIC_name'2'
$backendPool = New-AzureRmApplicationGatewayBackendAddressPool -Name $BackendPool_name `
  -BackendIPAddresses $address1.ipconfigurations[0].privateipaddress, $address2.ipconfigurations[0].privateipaddress

$probe = New-AzureRmApplicationGatewayProbeConfig -Name $probe_name -Protocol $Protocol -HostName '127.0.0.1' -Path '/'  `
  -Interval $IntervalTime -Timeout $RequestTime -UnhealthyThreshold $UnhealthyThreshold
$poolSettings = New-AzureRmApplicationGatewayBackendHttpSettings `
  -Name $PoolSetting_name -Port $BackendPoolPort -Protocol $Protocol -CookieBasedAffinity Enabled -Probe $probe -RequestTimeout $RequestTime


#Create the listener and add a rule

$defaultlistener = New-AzureRmApplicationGatewayHttpListener -Name $Listener_name `
  -Protocol $Protocol -FrontendIPConfiguration $fipconfig -FrontendPort $frontendport
$frontendRule = New-AzureRmApplicationGatewayRequestRoutingRule -Name rule1 -RuleType Basic -HttpListener $defaultlistener `
  -BackendAddressPool $backendPool -BackendHttpSettings $poolSettings


#Create the application gateway

$sku = New-AzureRmApplicationGatewaySku -Name $AG_sku_name -Tier $AG_Tier_name -Capacity 2

Write-Host 
$a = Get-Date -UFormat %T
Write-Host "Starting to build $AppGateway at $a " -ForegroundColor DarkYellow
Write-Host 

$gw = Get-AzureRmApplicationGateway -ResourceGroupName $resourceGroup -Name $AppGateway -ErrorAction Ignore
if( ! $gw ) {
    $gw = New-AzureRmApplicationGateway -Name $AppGateway `
          -ResourceGroupName $resourceGroup `
          -Location $location `
          -BackendAddressPools $backendPool `
          -Probes $probe `
          -BackendHttpSettingsCollection $poolSettings `
          -FrontendIpConfigurations $fipconfig `
          -GatewayIpConfigurations $gipconfig `
          -FrontendPorts $frontendport `
          -HttpListeners $defaultlistener `
          -RequestRoutingRules $frontendRule `
          -Sku $sku `
          -AsJob
}

for ($i=1; $i -le 2; $i++)
{
     $a = Get-Date -UFormat %T
      Write-Host "Waiting fot starting $VMnames$i at $a " -ForegroundColor DarkYellow
    do 
    {

     $myvm = Get-AzureRMVM -ResourceGroupName $resourceGroup -Name $VMnames$i | Select-Object ProvisioningState

    } While ( ! $myvm[0].ProvisioningState.Contains("Succeeded") )
      Write-Host "Doing provisioning on $VMnames$i at $a " -ForegroundColor DarkYellow
      if ( $BackendPoolPort = 80 ) {
        Set-AzureRmVMExtension -ResourceGroupName $resourceGroup -ExtensionName IIS -VMName $VMnames$i -Location $location `
        -Publisher Microsoft.Compute -ExtensionType CustomScriptExtension -TypeHandlerVersion 1.4 `
        -SettingString '{"commandToExecute":"powershell Add-WindowsFeature Web-Server; powershell Add-Content -Path \"C:\\inetpub\\wwwroot\\Default.htm\" -Value $($env:computername)"}' 
      } else {
      Invoke-AzureRmVMRunCommand -ResourceGroupName $resourceGroup -Name $VMnames$i -CommandId 'RunPowerShellScript' `
           -ScriptPath "$provision_script" -Parameter @{"arg1" = $i} -AsJob
      }
}

$a = Get-Date -UFormat %T
#Start-Sleep -s 15
Write-Host "Waiting fot starting $AppGateway at $a " -ForegroundColor DarkYellow

do 
{
 $mygw = Get-AzureRmApplicationGateway -ResourceGroupName $resourceGroup -Name $AppGateway | Select-Object ProvisioningState
} While ( ! $mygw[0].ProvisioningState.Contains("Succeeded") )

$a = Get-Date -UFormat %T
Write-Host "All have done at $a " -ForegroundColor Green
