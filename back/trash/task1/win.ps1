$resourceGroup = "akostivRG01"
$location = "East US"
$vmName = "VM"

## Storage
$StorageName = $resourceGroup + "storage1"
$StorageType = "Standard_GRS"
$OSDiskName = $resourceGroup + '-' + "osdisk"
$DataDiskName = $resourceGroup + '-' + "datadisk"

$Password = ConvertTo-SecureString 'PaSw0rD$ ' -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("azureuser", $Password)

New-AzureRmResourceGroup -Name $resourceGroup -Location $location

$StorageAcc = New-AzureRmStorageAccount -ResourceGroupName $resourceGroup -Name $StorageName.ToLower() -Type $StorageType -Location $location
$OSDiskUri = $StorageAcc.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + ".vhd"
$DataDiskUri = $StorageAcc.PrimaryEndpoints.Blob.ToString() + "vhds/" + $DataDiskName + ".vhd"


$subnetCfg = New-AzureRmVirtualNetworkSubnetConfig -Name $resourceGroup'_'Subnet -AddressPrefix 192.168.1.0/24
$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Location $location `
  -Name $resourceGroup'_'vNET -AddressPrefix 192.168.0.0/16 -Subnet $subnetCfg
$pip = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location `
  -Name $resourceGroup'_'"PIP" -AllocationMethod Static -IdleTimeoutInMinutes 4
$pip | Select-Object -Property Name, IpAddress
$nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig -Name $resourceGroup'_'NSG_RuleRDP  -Protocol Tcp `
  -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
  -DestinationPortRange 3389 -Access Allow
$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location `
  -Name $resourceGroup'_'NSG -SecurityRules $nsgRuleRDP
$nic = New-AzureRmNetworkInterface -Name $resourceGroup'_'Nic -ResourceGroupName $resourceGroup -Location $location `
  -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id
$vmCfg = New-AzureRmVMConfig -VMName $resourceGroup'_'$vmName -VMSize Standard_D1 | `
Set-AzureRmVMOperatingSystem -Windows -ComputerName $resourceGroup$vmName -Credential $cred | `
Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2016-Datacenter -Version latest | `
Set-AzureRmVMOSDisk -Name $OSDiskName -VhdUri $OSDiskUri -CreateOption FromImage | `
Add-AzureRmVMDataDisk -Name $DataDiskName -VhdUri $DataDiskUri -Caching 'ReadOnly' -DiskSizeInGB 10 -Lun 0 -CreateOption Empty | `
Add-AzureRmVMNetworkInterface -Id $nic.Id

New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vmCfg
#New-AzureRmVM -ResourceGroupName $resourceGroup -DiskFile