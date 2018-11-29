$resourceGroup             = "RG003"
$location                  = "East US"
$VMSize                    = 'Standard_DS1_v2'
$VMnames                   = $resourceGroup + "VM"
$ManDataDiskNameW          = $resourceGroup + "MAN_DATADISK"

$VNet_Name                 = $resourceGroup + "_VNet"
$VNet_Address              = '10.0.0.0/16'
$SubNet_Name               = $resourceGroup + "_Subnet"
$SubNet_Address            = '10.0.1.0/24'
$NSG_Name                  = $resourceGroup + "_NSG"
$PublicIPAddress_Name      = $resourceGroup + "_PublicIPAddress"
$AvailabilitySet_name      = $resourceGroup + "_AvailabilitySet"
$NIC_name                  = $resourceGroup + "_NIC"
$StorageTypeManaged = "Standard_LRS"
$DataDiskSize = 10

$FrontendIPConfig          = "FrontendIPConfig"

$BackendPool_name          = "BackendPool"
$FrontendPortWeb              = 80
$BackendPortWeb               = 8080
$LoadBalancer_Name         = $resourceGroup + "LB"
$LoadBalancerRuleWeb       = 'LBRuleWeb'

# AG probe setiing
$probe_name                = "probe01"
$ProbeProtocol             = "Http"
$ProbePort                 = 80
$IntervalTime              = 5
$ProbeCount        = 2
# windows VM init setting
$WPublisherName            = 'MicrosoftWindowsServer' 
$WOffer                    = 'WindowsServer' 
$WSkus                     = '2016-Datacenter' 
$WVersion                  = 'latest'
$UserName = 'azureuser'
$Passwd = 'Pa$$w0rd'

$provision_script = 'customiis.ps1'

$Password = ConvertTo-SecureString $Passwd -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($UserName, $Password)
$diskConfig = New-AzureRmDiskConfig -SkuName $StorageTypeManaged -Location $location -CreateOption Empty -DiskSizeGB $DataDiskSize

New-AzureRmResourceGroup -Name $resourceGroup -Location $location
$subnet = New-AzureRmVirtualNetworkSubnetConfig -Name $SubNet_Name -AddressPrefix $SubNet_Address
$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Name $VNet_Name -AddressPrefix $VNet_Address -Location $location -Subnet $subnet
$publicIp = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Name $PublicIPAddress_Name -Location $location -AllocationMethod Dynamic
$feip = New-AzureRmLoadBalancerFrontendIpConfig -Name $FrontendIPConfig -PublicIpAddress $publicIp
$bepool = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name $BackendPool_name
$probe = New-AzureRmLoadBalancerProbeConfig -Name $probe_name -Protocol $ProbeProtocol -Port $ProbePort -RequestPath / -IntervalInSeconds $IntervalTime -ProbeCount $ProbeCount
$rule = New-AzureRmLoadBalancerRuleConfig -Name $LoadBalancerRuleWeb -Protocol Tcp -Probe $probe -FrontendPort $FrontendPortWeb -BackendPort $BackendPortWeb -FrontendIpConfiguration $feip -BackendAddressPool $bePool
$lb = New-AzureRmLoadBalancer -ResourceGroupName $resourceGroup -Name $LoadBalancer_Name  -Location $location `
  -FrontendIpConfiguration $feip -BackendAddressPool $bepool -Probe $probe -LoadBalancingRule $rule 

$rule1 = New-AzureRmNetworkSecurityRuleConfig -Name 'NSGRuleHTTP' -Description 'Allow HTTP' -Access Allow -Protocol Tcp -Direction Inbound -Priority 2000 `
  -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange $BackendPortWeb

$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name $NSG_Name -SecurityRules $rule1

$AvailabilitySet = New-AzureRmAvailabilitySet -Location $location -Name $AvailabilitySet_name -ResourceGroupName $resourceGroup -Sku aligned -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 2

for ($i=1; $i -le 2; $i++)
{
  $DataDisk_w = New-AzureRmDisk -DiskName $ManDataDiskNameW$i -Disk $diskConfig -ResourceGroupName $resourceGroup
    
  $nic = New-AzureRmNetworkInterface -Name $NIC_name$i -ResourceGroupName $resourceGroup -Location $location -LoadBalancerBackendAddressPool $bepool -NetworkSecurityGroup $nsg -Subnet $vnet.Subnets[0]

  $vm = New-AzureRmVMConfig -VMName $VMnames$i -VMSize $VMSize -AvailabilitySetID $AvailabilitySet.Id
  $vm = Set-AzureRmVMOperatingSystem -VM $vm -Windows -ComputerName $VMnames$i -Credential $cred
  $vm = Set-AzureRmVMSourceImage -VM $vm -PublisherName $WPublisherName -Offer $WOffer -Skus $WSkus -Version $WVersion
  $vm = Add-AzureRmVMDataDisk -VM $vm -Name $ManDataDiskNameW$i -CreateOption Attach -Lun 1 -ManagedDiskId $DataDisk_w.Id
  $vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id
  $vm = Set-AzureRmVMBootDiagnostics -VM $vm -Disable
 
  New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vm -AsJob
}

for ($i=1; $i -le 2; $i++)
{
    do {
     $myvm = Get-AzureRMVM -ResourceGroupName $resourceGroup -Name $VMnames$i | Select-Object ProvisioningState
    } While ( ! $myvm[0].ProvisioningState.Contains("Succeeded") )
      Set-AzureRmVMExtension -ResourceGroupName lab1 -ExtensionName IIS -VMName LAB1VM1 -Location eastus -Publisher Microsoft.Compute -ExtensionType CustomScriptExtension -TypeHandlerVersion 1.4 -SettingString '{"commandToExecute":"powershell Add-WindowsFeature Web-Server; powershell mkdir "$env:systemdrive\inetpub\hello""}' -AsJob
}