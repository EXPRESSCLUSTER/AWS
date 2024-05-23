$Ports = Get-NetFirewallRule -DisplayName 'EXPRESSCLUSTER*' | Format-Table -AutoSize -Property DisplayName,
@{Name='Protocol';Expression={($PSItem | Get-NetFirewallPortFilter).Protocol}},
@{Name='LocalPort';Expression={($PSItem | Get-NetFirewallPortFilter).LocalPort}},
Enabled

If ($Ports -eq $null){
  Write-Output "No ECX ports found."
}
Else {
 Write-Output $Ports
}

$ECXservices = Get-Service -DisplayName EXPRESSCLUSTER* | Select-Object -Property DisplayName, Name, Status, Starttype
Write-Output $ECXservices
If ($ECXservices -eq $null){
  Write-Host "No EXPRESSCLUSTER services found."
}
