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


# Create network resources

# Create a virtual network.
$subnet = New-AzureRmVirtualNetworkSubnetConfig -Name $SubNet_Name -AddressPrefix $SubNet_Address
##$backendSubnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name $BackendSubnet_Name -AddressPrefix $BackendSubnet_Address

$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Name $VNet_Name -ErrorAction Ignore
if( ! $vnet ) {
    $vnet = New-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Location $location -Name $VNet_Name -AddressPrefix $VNet_Address  `
      -Subnet $subnet
}

# Create a public IP address.
$publicIp = Get-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Name $PublicIPAddressName -ErrorAction Ignore
if( ! $publicIp ) {
        $publicIp = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location  `
            -Name $PublicIPAddressName -AllocationMethod Dynamic
}
## $lbPIP = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location -AllocationMethod "Static" -Name "myLBPIP"

# Create a front-end IP configuration for the website.
$feip = New-AzureRmLoadBalancerFrontendIpConfig -Name 'myFrontEndPool' -PublicIpAddress $publicIp

# Create the back-end address pool.
$bepool = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name $BackendPool_name

# Creates a load balancer probe on port 80.
$probe = New-AzureRmLoadBalancerProbeConfig -Name $probe_name -Protocol Http -Port 80 `
  -RequestPath / -IntervalInSeconds 360 -ProbeCount 5

# Creates a load balancer rule for port 80.
$rule = New-AzureRmLoadBalancerRuleConfig -Name 'myLoadBalancerRuleWeb' -Protocol Tcp `
  -Probe $probe -FrontendPort 80 -BackendPort 80 `
  -FrontendIpConfiguration $feip -BackendAddressPool $bePool

# Create three NAT rules for port 3389.
$natrule1 = New-AzureRmLoadBalancerInboundNatRuleConfig -Name 'myLoadBalancerRDP1' -FrontendIpConfiguration $feip `
  -Protocol tcp -FrontendPort 4221 -BackendPort 3389

$natrule2 = New-AzureRmLoadBalancerInboundNatRuleConfig -Name 'myLoadBalancerRDP2' -FrontendIpConfiguration $feip `
  -Protocol tcp -FrontendPort 4222 -BackendPort 3389

# Create a load balancer.
$lb = New-AzureRmLoadBalancer -ResourceGroupName $resourceGroup -Name $LoadBalancer_Name -Location $location `
  -FrontendIpConfiguration $feip -BackendAddressPool $bepool `
  -Probe $probe -LoadBalancingRule $rule -InboundNatRule $natrule1,$natrule2

# Create a network security group rule for port 3389.
$rule1 = New-AzureRmNetworkSecurityRuleConfig -Name 'myNetworkSecurityGroupRuleRDP' -Description 'Allow RDP' `
  -Access Allow -Protocol Tcp -Direction Inbound -Priority 1000 `
  -SourceAddressPrefix Internet -SourcePortRange * `
  -DestinationAddressPrefix * -DestinationPortRange 3389

# Create a network security group rule for port 80.
$rule2 = New-AzureRmNetworkSecurityRuleConfig -Name 'myNetworkSecurityGroupRuleHTTP' -Description 'Allow HTTP' `
  -Access Allow -Protocol Tcp -Direction Inbound -Priority 2000 `
  -SourceAddressPrefix Internet -SourcePortRange * `
  -DestinationAddressPrefix * -DestinationPortRange 80

# Create a network security group
$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location `
-Name 'myNetworkSecurityGroup' -SecurityRules $rule1,$rule2

# Create three virtual network cards and associate with public IP address and NSG.
$nicVM1 = New-AzureRmNetworkInterface -ResourceGroupName $resourceGroup -Location $location `
  -Name 'MyNic1' -LoadBalancerBackendAddressPool $bepool -NetworkSecurityGroup $nsg `
  -LoadBalancerInboundNatRule $natrule1 -Subnet $vnet.Subnets[0]

$nicVM2 = New-AzureRmNetworkInterface -ResourceGroupName $resourceGroup -Location $location `
  -Name 'MyNic2' -LoadBalancerBackendAddressPool $bepool -NetworkSecurityGroup $nsg `
  -LoadBalancerInboundNatRule $natrule2 -Subnet $vnet.Subnets[0]

# Create an availability set.
$as = New-AzureRmAvailabilitySet -ResourceGroupName $resourceGroup -Location $location `
  -Name 'MyAvailabilitySet' -Sku Aligned -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 2

# Create three virtual machines.

# ############## VM1 ###############

# Create a virtual machine configuration
$vmConfig = New-AzureRmVMConfig -VMName 'myVM1' -VMSize Standard_DS2 -AvailabilitySetId $as.Id | `
  Set-AzureRmVMOperatingSystem -Windows -ComputerName 'myVM1' -Credential $cred | `
  Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer `
  -Skus 2016-Datacenter -Version latest | Add-AzureRmVMNetworkInterface -Id $nicVM1.Id

# Create a virtual machine
$vm1 = New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vmConfig

Invoke-AzureRmVMRunCommand -ResourceGroupName $resourceGroup -Name 'myVM1' -CommandId 'RunPowerShellScript' `
-ScriptPath "$provision_script" -Parameter @{"arg1" = $i} -AsJob

# ############## VM2 ###############

# Create a virtual machine configuration
$vmConfig = New-AzureRmVMConfig -VMName 'myVM2' -VMSize Standard_DS2 -AvailabilitySetId $as.Id | `
  Set-AzureRmVMOperatingSystem -Windows -ComputerName 'myVM2' -Credential $cred | `
  Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer `
  -Skus 2016-Datacenter -Version latest | Add-AzureRmVMNetworkInterface -Id $nicVM2.Id

# Create a virtual machine
$vm2 = New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vmConfig

Invoke-AzureRmVMRunCommand -ResourceGroupName $resourceGroup -Name 'myVM2' -CommandId 'RunPowerShellScript' `
-ScriptPath "$provision_script" -Parameter @{"arg1" = $i} -AsJob
