$resourceGroupName = 'RG001'
$location = 'France Central'
$RGpath = 'rg.json'
$FilePath = 'task5.json'
$parametersFilePath = 'task5.param.json'

New-AzureRmDeployment `
  -Name job0$(Get-Random -Minimum 10 -Maximum 99) `
  -Location $location `
  -TemplateFile $RGpath `
  -rgName $resourceGroupName `
  -rgLocation $location

 
New-AzureRmResourceGroupDeployment  `
  -Name job1$(Get-Random -Minimum 10 -Maximum 99)  `
  -TemplateFile $FilePath  `
  -TemplateParameterFile $parametersFilePath  `
  -ResourceGroupName $resourceGroupName

