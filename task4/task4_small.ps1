# You can write your azure powershell scripts inline here. 
# You can also pass predefined and custom variables to this script using arguments

$webappname1=$env:webapp1
$webappname2=$env:webapp2
$location="West Europe"
$ResourceGroup = "StudentsListRGdevops" 

# Create a resource group.
New-AzureRmResourceGroup -Name $ResourceGroup -Location $location -Force

# Create an App Service plan in Free tier.
New-AzureRmAppServicePlan -Name $webappname1 -Location $location -ResourceGroupName $ResourceGroup -Tier Free
New-AzureRmAppServicePlan -Name $webappname2 -Location $location -ResourceGroupName $ResourceGroup -Tier Free

# Create a web app.
New-AzureRmWebApp -Name $webappname1 -Location $location -AppServicePlan $webappname1 -ResourceGroupName $ResourceGroup 
New-AzureRmWebApp -Name $webappname2 -Location $location -AppServicePlan $webappname2 -ResourceGroupName $ResourceGroup 