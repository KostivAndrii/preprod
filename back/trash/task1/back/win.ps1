$resourceGroup = "wRG1"
$location = "East US"
$vmName = "VM"

## Storage
$StorageName = $resourceGroup + "storage"
$StorageType = "Standard_GRS"
$OSDiskName = $resourceGroup + '-' + "osdick"
##$VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -Name $OSDiskName -VhdUri $OSDiskUri -CreateOption FromImage

#$cred = Get-Credential -Message "Enter a username and password for the virtual machine."
$securePassword = ConvertTo-SecureString ' ' -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("azureuser", $securePassword)

New-AzureRmResourceGroup -Name $resourceGroup -Location $location

# Storage
$StorageAccount = New-AzureRmStorageAccount -ResourceGroupName $resourceGroup -Name $StorageName.ToLower() -Type $StorageType -Location $location
$OSDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + ".vhd"


$subnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name $resourceGroup'_'Subnet -AddressPrefix 192.168.1.0/24
$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Location $location `
  -Name $resourceGroup'_'vNET -AddressPrefix 192.168.0.0/16 -Subnet $subnetConfig
$pip = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location `
  -Name $resourceGroup'_'"PIP" -AllocationMethod Static -IdleTimeoutInMinutes 4
$pip | Select-Object -Property Name, IpAddress
#| Select-object -property Name, IpAddress
$nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig -Name $resourceGroup'_'NSG_RuleRDP  -Protocol Tcp `
  -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
  -DestinationPortRange 3389 -Access Allow
$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location `
  -Name $resourceGroup'_'NSG -SecurityRules $nsgRuleRDP
$nic = New-AzureRmNetworkInterface -Name $resourceGroup'_'Nic -ResourceGroupName $resourceGroup -Location $location `
  -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id
$vmConfig = New-AzureRmVMConfig -VMName $resourceGroup'_'$vmName -VMSize Standard_D1 | `
Set-AzureRmVMOperatingSystem -Windows -ComputerName $resourceGroup$vmName -Credential $cred | `
Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2016-Datacenter -Version latest | `
Set-AzureRmVMOSDisk -Name $OSDiskName -VhdUri $OSDiskUri -CreateOption FromImage | `
Add-AzureRmVMNetworkInterface -Id $nic.Id

New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vmConfig
#New-AzureRmVM -ResourceGroupName $resourceGroup -DiskFile