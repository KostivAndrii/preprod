$resourceGroup = "akostivRG01"
$location = "East US"
$vmName = "VM"
$sshPublicKey = Get-Content "$env:USERPROFILE\.ssh\id_rsa.pub"

## Storage
$StorageName = $resourceGroup.ToLower() + "storage"
$StorageType = "Standard_GRS"
$OSDiskName = $resourceGroup + '-' + "osdisk"

$Password = ConvertTo-SecureString 'PaSw0rD$' -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("azureuser", $Password)

########################

New-AzureRmResourceGroup -Name $resourceGroup -Location $location

$StorageAcc = New-AzureRmStorageAccount -ResourceGroupName $resourceGroup -Name $StorageName -Type $StorageType -Location $location
$OSDiskUri_w = $StorageAcc.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + "w.vhd"
$OSDiskUri_l = $StorageAcc.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + "l.vhd"

$subnetCfg = New-AzureRmVirtualNetworkSubnetConfig -Name $resourceGroup'_'Subnet -AddressPrefix 192.168.1.0/24
$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Location $location `
  -Name $resourceGroup'_'vNET -AddressPrefix 192.168.0.0/16 -Subnet $subnetCfg

#ubuntu
$pip_l = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location `
  -Name $resourceGroup"_PIP_L" -AllocationMethod Static -IdleTimeoutInMinutes 4
echo 'Linux public IP:'
$pip_l | Select-Object -Property IpAddress

$nsgRuleSSH = New-AzureRmNetworkSecurityRuleConfig -Name $resourceGroup'_'NSG_Rule_SSH  -Protocol Tcp `
  -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
  -DestinationPortRange 22 -Access Allow

$nsg_ssh = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location `
  -Name $resourceGroup'_'NSG_SSH -SecurityRules $nsgRuleSSH

$nic_l = New-AzureRmNetworkInterface -Name $resourceGroup'_'Nic_L -ResourceGroupName $resourceGroup -Location $location `
  -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip_l.Id -NetworkSecurityGroupId $nsg_ssh.Id

$vmCfg_l = New-AzureRmVMConfig -VMName $resourceGroup'_'$vmName'_L' -VMSize Standard_D1 | `
Set-AzureRmVMOperatingSystem -Linux -ComputerName $resourceGroup$vmName -Credential $cred -DisablePasswordAuthentication | `
Set-AzureRmVMSourceImage -PublisherName Canonical -Offer UbuntuServer -Skus 16.04-LTS -Version latest | `
Set-AzureRmVMOSDisk -Name $OSDiskName'-l' -VhdUri $OSDiskUri_l -CreateOption FromImage | `
Add-AzureRmVMSshPublicKey -KeyData $sshPublicKey -Path "/home/azureuser/.ssh/authorized_keys" | `
Add-AzureRmVMNetworkInterface -Id $nic_l.Id

New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vmCfg_l


#windows
$pip_w = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location `
  -Name $resourceGroup"_PIP_W" -AllocationMethod Static -IdleTimeoutInMinutes 4
echo 'Windows public IP:'
$pip_w | Select-Object -Property IpAddress

$nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig -Name $resourceGroup'_'NSG_Rule_RDP  -Protocol Tcp `
  -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
  -DestinationPortRange 3389 -Access Allow

$nsg_rdp = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location `
  -Name $resourceGroup'_'NSG_RDP -SecurityRules $nsgRuleRDP

$nic_w = New-AzureRmNetworkInterface -Name $resourceGroup'_'Nic_W -ResourceGroupName $resourceGroup -Location $location `
  -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip_w.Id -NetworkSecurityGroupId $nsg_dp.Id

$vmCfg_w = New-AzureRmVMConfig -VMName $resourceGroup'_'$vmName'_W' -VMSize Standard_D1 | `
Set-AzureRmVMOperatingSystem -Windows -ComputerName $resourceGroup$vmName -Credential $cred | `
Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2016-Datacenter -Version latest | `
Set-AzureRmVMOSDisk -Name $OSDiskName'-w' -VhdUri $OSDiskUri_w -CreateOption FromImage | `
Add-AzureRmVMNetworkInterface -Id $nic_w.Id

New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vmCfg_w
