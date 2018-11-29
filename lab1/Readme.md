https://azurecitadel.github.io/workshops/arm/#index

BASH

cd lab1
az group create --name lab1 --location "West Europe"
#az group deployment create --name job1 --resource-group lab1 --template-file azuredeploy.json

rg=lab1
template=/mnt/c/myTemplates/lab1/azuredeploy.json
job=job2
parms="storageAccount=akostivsa001"
az group deployment create --name $job --parameters "$parms" --template-file $template --resource-group $rg

PowerShell

$rg="lab1"
$location="West Europe"
$template="C:\myTemplates\lab1\azuredeploy.json"
$job="job2"
$storageAccount="akostivsa001"
New-AzureRmResourceGroup -Name $rg -Location $location
New-AzureRmResourceGroupDeployment -Name $job -storageAccount $storageAccount -TemplateFile $template -ResourceGroupName $rg


You can also use the 
	az group deployment validate 
subcommand to syntactically validate a template file. The rest of the command switches are the same as 
	az group deployment create
, making it easy to include that in a workflow.

PowerShell can do exactly the same, replacing New-AzureRmResourceGroupDeployment with Test-AzureRmResourceGroupDeployment.


Using output
$storageAccount = (New-AzureRmResourceGroupDeployment -Name $job -storageAccountPrefix $storageAccountPrefix -TemplateFile $template -ResourceGroupName $rg).Outputs.storageAccount.Value
echo $storageAccount

$rg="lab1"
$job = 'job.' + ((Get-Date).ToUniversalTime()).tostring("MMddyy.HHmm")
$template="C:\myTemplates\lab1\azuredeploy.json"
$parms="c:\myTemplates\lab1\azuredeploy.parameters.json"
$storageAccount = (New-AzureRmResourceGroupDeployment -Name $job -TemplateParameterFile $parms -TemplateFile $template -ResourceGroupName $rg).Outputs.storageAccount.Value
echo "Storage account $storageAccount has been created."