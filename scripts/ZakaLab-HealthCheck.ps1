Import-Module ActiveDirectory
Import-Module GroupPolicy

$DomainDN = (Get-ADDomain).DistinguishedName

Write-Host "`n=== DOMAIN ==="
Get-ADDomain | Select-Object DNSRoot, NetBIOSName, DomainMode

Write-Host "`n=== CORE SERVICES ==="
Get-Service NTDS, DNS, Netlogon | Format-Table Name, Status -AutoSize

Write-Host "`n=== LAB USERS ==="
Get-ADUser -Filter * -SearchBase "OU=ZakaLab-Users,$DomainDN" |
Select-Object Name, SamAccountName, Enabled

Write-Host "`n=== LAB GROUPS ==="
Get-ADGroup -Filter * -SearchBase "OU=ZakaLab-Groups,$DomainDN" |
Select-Object Name, GroupScope, GroupCategory

Write-Host "`n=== CLIENT01 ==="
Get-ADComputer CLIENT01 | Select-Object Name, DistinguishedName

Write-Host "`n=== DEPARTMENT SHARE ==="
Get-SmbShare -Name 'Departments$' |
Select-Object Name, Path, FolderEnumerationMode

Write-Host "`n=== ZAKALAB GPOS ==="
Get-GPO -All |
Where-Object DisplayName -Like 'ZakaLab*' |
Select-Object DisplayName, GpoStatus
