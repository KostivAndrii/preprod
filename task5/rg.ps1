$resourceGroupName = 'RG0012'
$location = 'Korea South'

#New-AzureRmDeployment -Name demoEmptyRG$(Get-Random -Minimum 100 -Maximum 999) -Location $location `
#  -TemplateFile task5n.json -rgName $resourceGroupName -rgLocation $location
New-AzureRmDeployment `
  -Name job1 `
  -Location $location `
  -TemplateFile rg.json `
  -rgName $resourceGroupName `
  -rgLocation $location `
  -Verbose

 
New-AzureRmResourceGroupDeployment -Name job2 -TemplateFile task5.json -ResourceGroupName $resourceGroupName -Verbose

#for ($i=1; $i -le 2; $i++)
#{
#      Invoke-AzureRmVMRunCommand -ResourceGroupName $resourceGroupName -Name $resourceGroupName'_VM'$i -CommandId 'RunPowerShellScript' `
#           -ScriptPath "customiis.ps1" -Parameter @{"arg1" = $i} -AsJob
#}