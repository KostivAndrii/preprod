$resourceGroupName = 'RG001'
$location = 'Korea South'

#New-AzureRmDeployment -Name demoEmptyRG$(Get-Random -Minimum 100 -Maximum 999) -Location $location `
#  -TemplateFile task5n.json -rgName $resourceGroupName -rgLocation $location
 
New-AzureRmResourceGroupDeployment -Name job$(Get-Random -Minimum 100 -Maximum 999) `
 -TemplateFile task5.json -ResourceGroupName $resourceGroupName

#for ($i=1; $i -le 2; $i++)
#{
#      Invoke-AzureRmVMRunCommand -ResourceGroupName $resourceGroupName -Name $resourceGroupName'_VM'$i -CommandId 'RunPowerShellScript' `
#           -ScriptPath "customiis.ps1" -Parameter @{"arg1" = $i} -AsJob
#}