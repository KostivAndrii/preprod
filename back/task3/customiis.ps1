param([String]$arg1)
Add-WindowsFeature Web-Server
mkdir "$env:systemdrive\inetpub\hello"
Add-Content -Path "C:\inetpub\hello\Default.htm" -Value $(Write-Output "hello world$arg1")
New-IISSite -Name "Hello word!" -BindingInformation "*:8080:" -PhysicalPath "$env:systemdrive\inetpub\hello"
New-NetFirewallRule -DisplayName 'HTTP(S) Inbound' -Profile @('Domain', 'Private', 'Public') -Direction Inbound -Action Allow -Protocol TCP -LocalPort @('80', '8080')