$resourceGroup = "akostivRG01"
$location = "East US"
$StorageType = "Standard_LRS"

$vmName = "VM"
$vnetAddrPrefix = '192.168.0.0/16'
$subnetAddrPrefix = '192.168.1.0/24'
$sshPort = 22
$rdpPort = 3389
$rulesPriority = 1000
# VM size
$VMSize1 = 'Standard_D1'
$VMSize2 = 'Standard_D1'
# windows init
$WPublisherName = 'MicrosoftWindowsServer' 
$WOffer = 'WindowsServer' 
$WSkus = '2016-Datacenter' 
$WVersion = 'latest'
# linux init
$LPublisherName = 'Canonical' 
$LOffer = 'UbuntuServer' 
$LSkus ='16.04-LTS'
$LVersion = 'latest'                                                                             	
$sshPATH = "$env:USERPROFILE\.ssh\id_rsa.pub"
$authorized_key = "/home/azureuser/.ssh/authorized_keys"

$UserName = 'azureuser'
$Passwd = 'PaSw0rD$'

## Storage
$StorageName = $resourceGroup.ToLower() + "storage"
$OSDiskName = $resourceGroup + '-' + "osdisk"
$DataDiskName = $resourceGroup + '-' + "datadisk"
$ManDataDiskNameL = $resourceGroup + '-' + "man_datadisk_l"
$ManDataDiskNameW = $resourceGroup + '-' + "man_datadisk_w"

$Password = ConvertTo-SecureString $Passwd -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($UserName, $Password)

########################

New-AzureRmResourceGroup -Name $resourceGroup -Location $location

$diskConfig = New-AzureRmDiskConfig -SkuName $StorageType -Location $location -CreateOption Empty -DiskSizeGB 2
$dataDisk1w = New-AzureRmDisk -DiskName $ManDataDiskNameW -Disk $diskConfig -ResourceGroupName $resourceGroup
$dataDisk1l = New-AzureRmDisk -DiskName $ManDataDiskNameL -Disk $diskConfig -ResourceGroupName $resourceGroup

$StorageAcc = New-AzureRmStorageAccount -ResourceGroupName $resourceGroup -Name $StorageName -Type $StorageType -Location $location
$OSDiskUri_w = $StorageAcc.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + "w.vhd"
$DataDiskUri_w = $StorageAcc.PrimaryEndpoints.Blob.ToString() + "vhds/" + $DataDiskName + "w.vhd"
$OSDiskUri_l = $StorageAcc.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + "l.vhd"
$DataDiskUri_l = $StorageAcc.PrimaryEndpoints.Blob.ToString() + "vhds/" + $DataDiskName + "l.vhd"


$subnetCfg = New-AzureRmVirtualNetworkSubnetConfig -Name $resourceGroup'_'Subnet -AddressPrefix $subnetAddrPrefix
$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Location $location `
  -Name $resourceGroup'__'vNET -AddressPrefix $vnetAddrPrefix -Subnet $subnetCfg



#ubuntu
$pip_l = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location `
  -Name $resourceGroup"_L_PIP" -AllocationMethod Static -IdleTimeoutInMinutes 4

echo 'Linux public IP:'
$pip_l | Select-Object -Property IpAddress

$nsgRuleSSH = New-AzureRmNetworkSecurityRuleConfig -Name $resourceGroup"_L_NSG_Rule_SSH"  -Protocol Tcp `
  -Direction Inbound -Priority $rulesPriority -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
  -DestinationPortRange $sshPort -Access Allow

$nsg_ssh = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location `
  -Name $resourceGroup"_L_NSG_SSH" -SecurityRules $nsgRuleSSH

$nic_l = New-AzureRmNetworkInterface -Name $resourceGroup"_L_Nic" -ResourceGroupName $resourceGroup -Location $location `
  -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip_l.Id -NetworkSecurityGroupId $nsg_ssh.Id

$sshPublicKey = Get-Content $sshPATH

$vmCfg_l = New-AzureRmVMConfig -VMName $resourceGroup'_L_'$vmName -VMSize $VMSize2 | `
Set-AzureRmVMOperatingSystem -Linux -ComputerName $resourceGroup$vmName -Credential $cred -DisablePasswordAuthentication | `
Set-AzureRmVMSourceImage -PublisherName Canonical -Offer UbuntuServer -Skus 16.04-LTS -Version latest | `
#Set-AzureRmVMOSDisk -Name $OSDiskName'-l' -VhdUri $OSDiskUri_l -CreateOption FromImage | `
#Add-AzureRmVMDataDisk -Name $DataDiskName'-l' -VhdUri $DataDiskUri_l -Caching 'ReadOnly' -DiskSizeInGB 10 -Lun 1 -CreateOption Empty | `
Add-AzureRmVMDataDisk -Name $ManDataDiskNameL -CreateOption Attach -Lun 2 -ManagedDiskId $dataDisk1l.Id  | `
Add-AzureRmVMSshPublicKey -KeyData $sshPublicKey -Path $authorized_key | `
Add-AzureRmVMNetworkInterface -Id $nic_l.Id


New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vmCfg_l


#windows
$pip_w = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location `
  -Name $resourceGroup"_W_PIP" -AllocationMethod Static -IdleTimeoutInMinutes 4

echo 'Windows public IP:'
$pip_w | Select-Object -Property IpAddress

$nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig -Name $resourceGroup"_W_NSG_Rule_RDP"  -Protocol Tcp `
  -Direction Inbound -Priority $rulesPriority -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
  -DestinationPortRange $rdpPort -Access Allow

$nsg_rdp = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location `
  -Name $resourceGroup"_W_NSG_RDP" -SecurityRules $nsgRuleRDP

$nic_w = New-AzureRmNetworkInterface -Name $resourceGroup"_W_Nic" -ResourceGroupName $resourceGroup -Location $location `
  -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip_w.Id -NetworkSecurityGroupId $nsg_dp.Id

$vmCfg_w = New-AzureRmVMConfig -VMName $resourceGroup"_W_"$vmName -VMSize $VMSize2 | `
Set-AzureRmVMOperatingSystem -Windows -ComputerName $resourceGroup$vmName -Credential $cred | `
Set-AzureRmVMSourceImage -PublisherName $WPublisherName -Offer $WOffer -Skus $WSkus -Version $WVersion | `
#Set-AzureRmVMOSDisk -Name $OSDiskName'-w' -VhdUri $OSDiskUri_w -CreateOption FromImage | `
#Add-AzureRmVMDataDisk -Name $DataDiskName'-w' -VhdUri $DataDiskUri_w -Caching 'ReadOnly' -DiskSizeInGB 10 -Lun 1 -CreateOption Empty | `
Add-AzureRmVMDataDisk -Name $ManDataDiskNameW -CreateOption Attach -Lun 2 -ManagedDiskId $dataDisk1w.Id  | `
Add-AzureRmVMNetworkInterface -Id $nic_w.Id

New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vmCfg_w
