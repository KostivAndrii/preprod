$resourceGroupName = 'RG001'
$location = 'France Central'
$FilePath = 'task5.json'
$parametersFilePath = 'task5.param.json'

New-AzureRmDeployment `
  -Name job0$(Get-Random -Minimum 10 -Maximum 99) `
  -Location $location `
  -TemplateFile rg.json `
  -rgName $resourceGroupName `
  -rgLocation $location `
  -Verbose

 
New-AzureRmResourceGroupDeployment  `
  -Name job1$(Get-Random -Minimum 10 -Maximum 99)  `
  -TemplateFile $FilePath  `
  -TemplateParameterFile $parametersFilePath  `
  -ResourceGroupName $resourceGroupName  `
  -Verbose

