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
  $ProvisionApsent = $true  
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

$diskConfig = New-AzureRmDiskConfig -SkuName $StorageTypeManaged -Location $location -CreateOption Empty -DiskSizeGB $DataDiskSize


# Create a virtual network.
$subnet = New-AzureRmVirtualNetworkSubnetConfig -Name $SubNet_Name -AddressPrefix $SubNet_Address

$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Name $VNet_Name `
  -AddressPrefix $VNet_Address -Location $location -Subnet $subnet

# Create a public IP address.
$publicIp = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Name $PublicIPAddress_Name `
  -Location $location -AllocationMethod Dynamic

# Create a front-end IP configuration for the website.
$feip = New-AzureRmLoadBalancerFrontendIpConfig -Name $FrontendIPConfig -PublicIpAddress $publicIp

# Create the back-end address pool.
$bepool = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name $BackendPool_name

# Creates a load balancer probe on port 80.
$probe = New-AzureRmLoadBalancerProbeConfig -Name $probe_name -Protocol $ProbeProtocol -Port $ProbePort `
  -RequestPath / -IntervalInSeconds $IntervalTime -ProbeCount $ProbeCount

# Creates a load balancer rule for port 80.
$rule = New-AzureRmLoadBalancerRuleConfig -Name $LoadBalancerRuleWeb -Protocol Tcp `
  -Probe $probe -FrontendPort $FrontendPortWeb -BackendPort $BackendPortWeb `
  -FrontendIpConfiguration $feip -BackendAddressPool $bePool

# Create a load balancer.
$lb = New-AzureRmLoadBalancer -ResourceGroupName $resourceGroup -Name $LoadBalancer_Name  -Location $location `
  -FrontendIpConfiguration $feip -BackendAddressPool $bepool `
  -Probe $probe -LoadBalancingRule $rule #-InboundNatRule $natrule1,$natrule2


  # Create a network security group rule for port 80.
$rule1 = New-AzureRmNetworkSecurityRuleConfig -Name 'myNetworkSecurityGroupRuleHTTP' -Description 'Allow HTTP' `
  -Access Allow -Protocol Tcp -Direction Inbound -Priority 2000 `
  -SourceAddressPrefix Internet -SourcePortRange * `
  -DestinationAddressPrefix * -DestinationPortRange $BackendPortWeb

# Create a network security group
$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location `
-Name 'myNetworkSecurityGroup' -SecurityRules $rule1

# Create an availability set.
$AvailabilitySet = Get-AzureRmAvailabilitySet -ResourceGroupName $resourceGroup -Name $AvailabilitySet_name -ErrorAction Ignore
if( ! $AvailabilitySet ) {
    $AvailabilitySet = New-AzureRmAvailabilitySet -Location $location -Name $AvailabilitySet_name -ResourceGroupName $resourceGroup  `
       -Sku aligned -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 2
}


for ($i=1; $i -le 2; $i++)
{

  $DataDisk_w = New-AzureRmDisk -DiskName $ManDataDiskNameW$i -Disk $diskConfig -ResourceGroupName $resourceGroup
    
  $nic = Get-AzureRmNetworkInterface -Name $NIC_name$i -ResourceGroupName $resourceGroup -ErrorAction Ignore 
  if( ! $nic ) {
      $nic = New-AzureRmNetworkInterface -Name $NIC_name$i -ResourceGroupName $resourceGroup -Location $location  `
      -LoadBalancerBackendAddressPool $bepool -NetworkSecurityGroup $nsg `
      -Subnet $vnet.Subnets[0] #-LoadBalancerInboundNatRule $natrule1 
  }

  $vm = New-AzureRmVMConfig -VMName $VMnames$i -VMSize $VMSize -AvailabilitySetID $AvailabilitySet.Id
  $vm = Set-AzureRmVMOperatingSystem -VM $vm -Windows -ComputerName $VMnames$i -Credential $cred
  $vm = Set-AzureRmVMSourceImage -VM $vm -PublisherName $WPublisherName -Offer $WOffer -Skus $WSkus -Version $WVersion
  $vm = Add-AzureRmVMDataDisk -VM $vm -Name $ManDataDiskNameW -CreateOption Attach -Lun 1 -ManagedDiskId $DataDisk_w.Id
  $vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id
  $vm = Set-AzureRmVMBootDiagnostics -VM $vm -Disable
 
    
  $a = Get-Date -UFormat %T
  Write-Host "Starting to build $VMnames$i at $a " -ForegroundColor DarkYellow
  
  if( ! $(Get-AzureRMVM -ResourceGroupName $resourceGroup -Name $VMnames$i -ErrorAction Ignore) ) {
    New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vm -AsJob
  }  
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
      if ( $ProvisionApsent ) {
        Set-AzureRmVMExtension -ResourceGroupName $resourceGroup -ExtensionName IIS -VMName $VMnames$i -Location $location `
        -Publisher Microsoft.Compute -ExtensionType CustomScriptExtension -TypeHandlerVersion 1.4 `
        -SettingString '{"commandToExecute":"powershell Add-WindowsFeature Web-Server; powershell Add-Content -Path \"C:\\inetpub\\wwwroot\\Default.htm\" -Value $($env:computername)"}' -AsJob
      } else {
      Invoke-AzureRmVMRunCommand -ResourceGroupName $resourceGroup -Name $VMnames$i -CommandId 'RunPowerShellScript' `
           -ScriptPath "$provision_script" -Parameter @{"arg1" = $i} -AsJob
      }
}