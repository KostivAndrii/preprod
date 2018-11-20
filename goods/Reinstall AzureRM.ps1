Disconnect-AzureRmAccount
Remove-Module Azure*
$allModules = Get-Module -ListAvailable Azure*
foreach ($module in $allModules) {
  Write-Host ('Uninstalling {0} version {1}' -f $module.name,$module.version)
    try {
      Uninstall-Module -Name $module.name -Force
    } catch {
      Write-Host ("`t" + $_.Exception.Message)
    }
}
Install-Module -Name AzureRM
Import-Module -Name AzureRM