$resourceGroup = "akostivRG01"
$location = "East US"
$vmName = "VM"
$sshPublicKey = Get-Content "$env:USERPROFILE\.ssh\id_rsa.pub"


$Password = ConvertTo-SecureString 'PaSw0rD$' -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("azureuser", $Password)

########################

New-AzureRmResourceGroup -Name $resourceGroup -Location $location

$subnetCfg = New-AzureRmVirtualNetworkSubnetConfig -Name $resourceGroup'_'Subnet -AddressPrefix 192.168.1.0/24
$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Location $location `
  -Name $resourceGroup'__'vNET -AddressPrefix 192.168.0.0/16 -Subnet $subnetCfg

#ubuntu
$pip_l = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location `
  -Name $resourceGroup"_L_PIP" -AllocationMethod Static -IdleTimeoutInMinutes 4
echo 'Linux public IP:'
$pip_l | Select-Object -Property IpAddress

$nsgRuleSSH = New-AzureRmNetworkSecurityRuleConfig -Name $resourceGroup"_L_NSG_Rule_SSH"  -Protocol Tcp `
  -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
  -DestinationPortRange 22 -Access Allow

$nsg_ssh = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location `
  -Name $resourceGroup"_L_NSG_SSH" -SecurityRules $nsgRuleSSH

$nic_l = New-AzureRmNetworkInterface -Name $resourceGroup"_L_Nic" -ResourceGroupName $resourceGroup -Location $location `
  -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip_l.Id -NetworkSecurityGroupId $nsg_ssh.Id

$vmCfg_l = New-AzureRmVMConfig -VMName $resourceGroup'_L_'$vmName -VMSize Standard_D1 | `
Set-AzureRmVMOperatingSystem -Linux -ComputerName $resourceGroup$vmName -Credential $cred -DisablePasswordAuthentication | `
Set-AzureRmVMSourceImage -PublisherName Canonical -Offer UbuntuServer -Skus 16.04-LTS -Version latest | `
Add-AzureRmVMSshPublicKey -KeyData $sshPublicKey -Path "/home/azureuser/.ssh/authorized_keys" | `
Add-AzureRmVMNetworkInterface -Id $nic_l.Id

New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vmCfg_l


#windows
$pip_w = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location `
  -Name $resourceGroup"_W_PIP" -AllocationMethod Static -IdleTimeoutInMinutes 4
echo 'Windows public IP:'
$pip_w | Select-Object -Property IpAddress

$nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig -Name $resourceGroup"_W_NSG_Rule_RDP"  -Protocol Tcp `
  -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
  -DestinationPortRange 3389 -Access Allow

$nsg_rdp = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location `
  -Name $resourceGroup"_W_NSG_RDP" -SecurityRules $nsgRuleRDP

$nic_w = New-AzureRmNetworkInterface -Name $resourceGroup"_W_Nic" -ResourceGroupName $resourceGroup -Location $location `
  -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip_w.Id -NetworkSecurityGroupId $nsg_dp.Id

$vmCfg_w = New-AzureRmVMConfig -VMName $resourceGroup"_W_"$vmName -VMSize Standard_D1 | `
Set-AzureRmVMOperatingSystem -Windows -ComputerName $resourceGroup$vmName -Credential $cred | `
Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2016-Datacenter -Version latest | `
Add-AzureRmVMNetworkInterface -Id $nic_w.Id

New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vmCfg_w
