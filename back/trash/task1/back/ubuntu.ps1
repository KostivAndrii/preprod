$resourceGroup = "lRG1"
$location = "East US"
$vmName = "VM"

$securePassword = ConvertTo-SecureString ' ' -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("azureuser", $securePassword)

New-AzureRmResourceGroup -Name $resourceGroup -Location $location

$subnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name $resourceGroup'_'Subnet -AddressPrefix 192.168.1.0/24

$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Location $location `
  -Name $resourceGroup'_'vNET -AddressPrefix 192.168.0.0/16 -Subnet $subnetConfig

$pip = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location `
  -Name $resourceGroup'_'"mypip$(Get-Random)" -AllocationMethod Static -IdleTimeoutInMinutes 4

$nsgRuleSSH = New-AzureRmNetworkSecurityRuleConfig -Name $resourceGroup'_'NSG_Rule_SSH  -Protocol Tcp `
  -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
  -DestinationPortRange 22 -Access Allow

$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location `
  -Name $resourceGroup'_'NSG -SecurityRules $nsgRuleSSH

$nic = New-AzureRmNetworkInterface -Name $resourceGroup'_'Nic -ResourceGroupName $resourceGroup -Location $location `
  -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id

$vmConfig = New-AzureRmVMConfig -VMName $resourceGroup'_'$vmName -VMSize Standard_D1 |
Set-AzureRmVMOperatingSystem -Linux -ComputerName $resourceGroup$vmName -Credential $cred -DisablePasswordAuthentication |
Set-AzureRmVMSourceImage -PublisherName Canonical -Offer UbuntuServer -Skus 14.04.2-LTS -Version latest |
Add-AzureRmVMNetworkInterface -Id $nic.Id

$sshPublicKey = Get-Content "$env:USERPROFILE\.ssh\id_rsa.pub"
Add-AzureRmVMSshPublicKey -VM $vmconfig -KeyData $sshPublicKey -Path "/home/azureuser/.ssh/authorized_keys"

New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vmConfig
