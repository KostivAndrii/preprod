$appName = Read-Host -Prompt "Enter Application Principals Name"
$uri = "http://$appName"
$secret = Read-Host -Prompt "Provide Good Password!!!"
$pswd = ConvertTo-SecureString -String $secret -AsPlainText -Force

Login-AzureRmAccount

# Create the Azure AD app
$azureAdApplication = New-AzureRmADApplication -DisplayName $appName -HomePage $uri -IdentifierUris $uri -Password $pswd

# Create a Service Principal for the app
$svcprincipal = New-AzureRmADServicePrincipal -ApplicationId $azureAdApplication.ApplicationId

# Assign the Contributor RBAC role to the service principal
$roleassignment = New-AzureRmRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $azureAdApplication.ApplicationId.Guid

# Display the values for your application 
Write-Output "Save these values for using them in your application"
Write-Output "Subscription ID:" (Get-AzureRmContext).Subscription.SubscriptionId
Write-Output "Tenant ID:" (Get-AzureRmContext).Tenant.TenantId
Write-Output "Application ID:" $azureAdApplication.ApplicationId.Guid
Write-Output "Application Secret:" $secret