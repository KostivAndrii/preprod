# This script create 4 VM:  Linux/Windows with attached managed/unmanaged disks
# attached unmanaged disk belong to storage account and created in the time of creating VM
# attached managed disk created before creating VM but isn't belong to storage account

# General setting
$resourceGroup = "akostivRG01"
$location = "East US"
$StorageTypeManaged = "Standard_LRS"
$StorageTypeUnmanaged = "Standard_LRS"

# inventory configurating
$VMSize1 = 'Standard_D1'
$VMSize2 = 'Standard_D1'
$OSDiskSize = 30
$DataDiskSize = 10
$vnetAddrPrefix = '192.168.0.0/16'
$subnetAddrPrefix = '192.168.1.0/24'
$sshPort = 22
$rdpPort = 3389
$rulesPriority = 1000
# windows VM init setting
$WPublisherName = 'MicrosoftWindowsServer' 
$WOffer = 'WindowsServer' 
$WSkus = '2016-Datacenter' 
$WVersion = 'latest'
# linux VM init setting
$LPublisherName = 'Canonical' 
	$LOffer = 'UbuntuServer' 
$LSkus ='16.04-LTS'
$LVersion = 'latest'                                                                             	
$sshPATH = "$env:USERPROFILE\.ssh\id_rsa.pub"
$authorized_key = "/home/azureuser/.ssh/authorized_keys"

# user setting for login 
$UserName = 'azureuser'
$Passwd = 'PaSw0rD$'

# resource naming
$vmName = "VM"
$UM = 'UM'               # unmanager VM resources sufix
$L_prefix = '_L_'        # Linux VM resources sufix
$W_prefix = '_W_'        # Windows VM resources sufix
$SubNet = '_Subnet'
$vNET_ = '_vNET'
$PIP = 'PIP'
$NSG_Rule_SSH = 'NSG_Rule_SSH'
$NSG_SSH = 'NSG_SSH'
$NSG_Rule_RDP = 'NSG_Rule_RDP'
$NSG_RDP = 'NSG_RDP'
$NIC = 'Nic'

## Storage
$StorageName = $resourceGroup.ToLower() + "storage"
$OSDiskName = $resourceGroup + '-' + "osdisk"
$DataDiskName = $resourceGroup + '-' + "datadisk"
$ManOSDiskNameL = $resourceGroup + $L_prefix + "MAN_OSDISK"
$ManOSDiskNameW = $resourceGroup + $W_prefix + "MAN_OSDISK"
$ManDataDiskNameL = $resourceGroup + $L_prefix + "MAN_DATADISK"
$ManDataDiskNameW = $resourceGroup + $W_prefix + "MAN_DATADISK"


$Password = ConvertTo-SecureString $Passwd -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($UserName, $Password)



########################
if ( ! $(Get-AzureRmResourceGroup -Name $resourceGroup -ErrorAction Ignore)) {
            New-AzureRmResourceGroup -Name $resourceGroup -Location $location
}

$diskConfig = New-AzureRmDiskConfig -SkuName $StorageTypeManaged -Location $location -CreateOption Empty -DiskSizeGB $DataDiskSize

$DataDisk_w = Get-AzureRmDisk -DiskName $ManDataDiskNameW -ResourceGroupName $resourceGroup -ErrorAction Ignore
if ( ! $DataDisk_w ) {
    $DataDisk_w = New-AzureRmDisk -DiskName $ManDataDiskNameW -Disk $diskConfig -ResourceGroupName $resourceGroup
}

$DataDisk_l = Get-AzureRmDisk -DiskName $ManDataDiskNameL -ResourceGroupName $resourceGroup -ErrorAction Ignore
if ( ! $DataDisk_l ) {
    $DataDisk_l = New-AzureRmDisk -DiskName $ManDataDiskNameL -Disk $diskConfig -ResourceGroupName $resourceGroup
}

$StorageAcc = Get-AzureRmStorageAccount -ResourceGroupName $resourceGroup -Name $StorageName -ErrorAction Ignore
if( ! $StorageAcc ) {
    $StorageAcc = New-AzureRmStorageAccount -ResourceGroupName $resourceGroup -Name $StorageName -Type $StorageTypeUnmanaged -Location $location
}

$OSDiskUri_w = $StorageAcc.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + $W_prefix + $UM + ".vhd"
$DataDiskUri_w = $StorageAcc.PrimaryEndpoints.Blob.ToString() + "vhds/" + $DataDiskName + $W_prefix + $UM + ".vhd"
$OSDiskUri_l = $StorageAcc.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + $L_prefix + $UM + ".vhd"
$DataDiskUri_l = $StorageAcc.PrimaryEndpoints.Blob.ToString() + "vhds/" + $DataDiskName + $L_prefix + $UM + ".vhd"


$subnetCfg = New-AzureRmVirtualNetworkSubnetConfig -Name $resourceGroup$SubNet -AddressPrefix $subnetAddrPrefix

$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Name $resourceGroup$vNET_ -ErrorAction Ignore
if( ! $vnet ) {
    $vnet = New-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Location $location `
        -Name $resourceGroup$vNET_ -AddressPrefix $vnetAddrPrefix -Subnet $subnetCfg
}

# ubuntu VM
$pip_l = Get-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Name $resourceGroup$L_prefix$PIP -ErrorAction Ignore
if( ! $pip_l ) {
    $pip_l = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location `
        -Name $resourceGroup$L_prefix$PIP -AllocationMethod Static -IdleTimeoutInMinutes 4
}
$pip_l_um = Get-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Name $resourceGroup$L_prefix$PIP'_'$UM -ErrorAction Ignore
if( ! $pip_l_um ) {
    $pip_l_um = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location `
        -Name $resourceGroup$L_prefix$PIP'_'$UM -AllocationMethod Static -IdleTimeoutInMinutes 4
}

echo 'Linux public IP VM with managed DISK:'
$pip_l | Select-Object -Property IpAddress
echo 'Linux public IP VM with unmanaged DISK:'
$pip_l_um | Select-Object -Property IpAddress

$nsgRuleSSH = New-AzureRmNetworkSecurityRuleConfig -Name $resourceGroup$L_prefix$NSG_Rule_SSH  -Protocol Tcp `
  -Direction Inbound -Priority $rulesPriority -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
  -DestinationPortRange $sshPort -Access Allow

$nsgSSH = Get-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Name $resourceGroup$L_prefix$NSG_SSH -ErrorAction Ignore
if( ! $nsgSSH ) {
    $nsgSSH = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location `
        -Name $resourceGroup$L_prefix$NSG_SSH -SecurityRules $nsgRuleSSH
}

$nic_l = Get-AzureRmNetworkInterface -Name $resourceGroup$L_prefix$NIC -ResourceGroupName $resourceGroup -ErrorAction Ignore
if( ! $nic_l ) {
    $nic_l = New-AzureRmNetworkInterface -Name $resourceGroup$L_prefix$NIC -ResourceGroupName $resourceGroup -Location $location `
        -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip_l.Id -NetworkSecurityGroupId $nsgSSH.Id
}

$nic_l_um = Get-AzureRmNetworkInterface -Name $resourceGroup$L_prefix$NIC'_'$UM -ResourceGroupName $resourceGroup -ErrorAction Ignore
if( ! $nic_l_um ) {
    $nic_l_um = New-AzureRmNetworkInterface -Name $resourceGroup$L_prefix$NIC'_'$UM -ResourceGroupName $resourceGroup -Location $location `
        -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip_l_um.Id -NetworkSecurityGroupId $nsgSSH.Id
}

$sshPublicKey = Get-Content $sshPATH


$vmCfg_l = New-AzureRmVMConfig -VMName $resourceGroup$L_prefix$vmName -VMSize $VMSize2 | `
Set-AzureRmVMOperatingSystem -Linux -ComputerName $resourceGroup$vmName -Credential $cred -DisablePasswordAuthentication | `
Set-AzureRmVMSourceImage -PublisherName $LPublisherName -Offer $LOffer -Skus $LSkus -Version $LVersion | `
Add-AzureRmVMDataDisk -Name $ManDataDiskNameL -CreateOption Attach -Lun 1 -ManagedDiskId $DataDisk_l.Id  | `
Add-AzureRmVMSshPublicKey -KeyData $sshPublicKey -Path $authorized_key | `
Add-AzureRmVMNetworkInterface -Id $nic_l.Id

$vmCfg_l_um = New-AzureRmVMConfig -VMName $resourceGroup$L_prefix$vmName'_'$UM -VMSize $VMSize2 | `
Set-AzureRmVMOperatingSystem -Linux -ComputerName $resourceGroup$vmName$UM -Credential $cred -DisablePasswordAuthentication | `
Set-AzureRmVMSourceImage -PublisherName $LPublisherName -Offer $LOffer -Skus $LSkus -Version $LVersion | `
Set-AzureRmVMOSDisk -Name $OSDiskName'-l' -VhdUri $OSDiskUri_l -CreateOption FromImage | `
Add-AzureRmVMDataDisk -Name $DataDiskName'-l' -VhdUri $DataDiskUri_l -Caching 'ReadOnly' -DiskSizeInGB $DataDiskSize -Lun 1 -CreateOption Empty | `
Add-AzureRmVMSshPublicKey -KeyData $sshPublicKey -Path $authorized_key | `
Add-AzureRmVMNetworkInterface -Id $nic_l_um.Id


if( ! $(Get-AzureRMVM -ResourceGroupName $resourceGroup -Name $resourceGroup$L_prefix$vmName -ErrorAction Ignore) ) {
    New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vmCfg_l
}
if( ! $(Get-AzureRMVM -ResourceGroupName $resourceGroup -Name $resourceGroup$L_prefix$vmName'_'$UM -ErrorAction Ignore) ) {
    New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vmCfg_l_um
}


# windows VM
$pip_w = Get-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Name $resourceGroup$W_prefix$PIP -ErrorAction Ignore
if( ! $pip_w ) {
    $pip_w = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location `
        -Name $resourceGroup$W_prefix$PIP -AllocationMethod Static -IdleTimeoutInMinutes 4
}
$pip_w_um = Get-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Name $resourceGroup$W_prefix$PIP'_'$UM -ErrorAction Ignore
if( ! $pip_w_um ) {
    $pip_w_um = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location `
        -Name $resourceGroup$W_prefix$PIP'_'$UM -AllocationMethod Static -IdleTimeoutInMinutes 4
}

echo 'Windows public IP VM with managed DISK:'
$pip_w | Select-Object -Property IpAddress
echo 'Windows public IP VM with unmanaged DISK:'
$pip_w_um | Select-Object -Property IpAddress

$nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig -Name $resourceGroup$W_prefix$NSG_Rule_RDP  -Protocol Tcp `
  -Direction Inbound -Priority $rulesPriority -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
  -DestinationPortRange $rdpPort -Access Allow

$nsgRDP = Get-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Name $resourceGroup$W_prefix$NSG_RDP -ErrorAction Ignore
if( ! $nsgRDP ) {
    $nsgRDP = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location `
        -Name $resourceGroup$W_prefix$NSG_RDP -SecurityRules $nsgRuleRDP
}

$nic_w = Get-AzureRmNetworkInterface -Name $resourceGroup$W_prefix$NIC -ResourceGroupName $resourceGroup -ErrorAction Ignore
if( ! $nic_w ) {
    $nic_w = New-AzureRmNetworkInterface -Name $resourceGroup$W_prefix$NIC -ResourceGroupName $resourceGroup -Location $location `
      -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip_w.Id -NetworkSecurityGroupId $nsgRDP.Id
}
$nic_w_um = Get-AzureRmNetworkInterface -Name $resourceGroup$W_prefix$NIC'_'$UM -ResourceGroupName $resourceGroup -ErrorAction Ignore
if( ! $nic_w_um ) {
    $nic_w_um = New-AzureRmNetworkInterface -Name $resourceGroup$W_prefix$NIC'_'$UM -ResourceGroupName $resourceGroup -Location $location `
      -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip_w_um.Id -NetworkSecurityGroupId $nsgRDP.Id
}

$vmCfg_w = New-AzureRmVMConfig -VMName $resourceGroup$W_prefix$vmName -VMSize $VMSize2 | `
Set-AzureRmVMOperatingSystem -Windows -ComputerName $resourceGroup$vmName -Credential $cred | `
Set-AzureRmVMSourceImage -PublisherName $WPublisherName -Offer $WOffer -Skus $WSkus -Version $WVersion | `
Add-AzureRmVMDataDisk -Name $ManDataDiskNameW -CreateOption Attach -Lun 1 -ManagedDiskId $DataDisk_w.Id  | `
Add-AzureRmVMNetworkInterface -Id $nic_w.Id

$vmCfg_w_um = New-AzureRmVMConfig -VMName $resourceGroup$W_prefix$vmName'_'$UM -VMSize $VMSize2 | `
Set-AzureRmVMOperatingSystem -Windows -ComputerName $resourceGroup$vmName$UM -Credential $cred | `
Set-AzureRmVMSourceImage -PublisherName $WPublisherName -Offer $WOffer -Skus $WSkus -Version $WVersion | `
Set-AzureRmVMOSDisk -Name $OSDiskName'-w' -VhdUri $OSDiskUri_w -CreateOption FromImage | `
Add-AzureRmVMDataDisk -Name $DataDiskName'-w' -VhdUri $DataDiskUri_w -Caching 'ReadOnly' -DiskSizeInGB $DataDiskSize -Lun 1 -CreateOption Empty | `
Add-AzureRmVMNetworkInterface -Id $nic_w_um.Id

if( ! $(Get-AzureRMVM -ResourceGroupName $resourceGroup -Name $resourceGroup$W_prefix$vmName -ErrorAction Ignore) ) {
    New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vmCfg_w
}
if( ! $(Get-AzureRMVM -ResourceGroupName $resourceGroup -Name $resourceGroup$W_prefix$vmName'_'$UM -ErrorAction Ignore) ) {
    New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vmCfg_w_um
}
