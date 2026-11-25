#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ManagerIp,
    [string]$AgentGroup = 'windows',
    [string]$WazuhMsiUrl = 'https://packages.wazuh.com/4.x/windows/wazuh-agent-4.14.10-1.msi',
    [string]$MsiPath,
    [switch]$InstallSysmon,
    [string]$SysmonExePath,
    [int]$EventsPort = 51514,
    [int]$EnrollPort = 51515
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Import-Module (Join-Path $PSScriptRoot '..\lib\Common.psm1') -Force

Write-Step "Checking connectivity to Wazuh Manager ($ManagerIp)"
Test-TcpPort -TargetHost $ManagerIp -Port $EventsPort | Out-Null
Test-TcpPort -TargetHost $ManagerIp -Port $EnrollPort | Out-Null

if (-not $MsiPath) {
    $MsiPath = Join-Path $env:TEMP 'wazuh-agent.msi'
    Write-Step "Downloading Wazuh Agent MSI"
    Invoke-WebRequest -Uri $WazuhMsiUrl -OutFile $MsiPath -UseBasicParsing
}
if (-not (Test-Path $MsiPath)) { throw "MSI not found: $MsiPath" }

Write-Step "Installing Wazuh Agent (Manager=$ManagerIp, Group=$AgentGroup)"
$msiArgs = @(
    '/i', "`"$MsiPath`"",
    '/q',
    "WAZUH_MANAGER=`"$ManagerIp`"",
    "WAZUH_AGENT_GROUP=`"$AgentGroup`"",
    "WAZUH_REGISTRATION_SERVER=`"$ManagerIp`""
)
$proc = Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -PassThru
if ($proc.ExitCode -ne 0) { throw "Wazuh MSI install failed with exit code $($proc.ExitCode)" }

if ($InstallSysmon) {
    $sysmonCfg = Join-Path $PSScriptRoot '..\..\wazuh\agent-configs\sysmonconfig.xml'
    if (-not $SysmonExePath) {
        $zip = Join-Path $env:TEMP 'Sysmon.zip'
        $dir = Join-Path $env:TEMP 'Sysmon'
        Invoke-WebRequest -Uri 'https://download.sysinternals.com/files/Sysmon.zip' -OutFile $zip -UseBasicParsing
        Expand-Archive -Path $zip -DestinationPath $dir -Force
        $SysmonExePath = Join-Path $dir 'Sysmon64.exe'
    }
    Write-Step 'Installing Sysmon with CCDC sysmonconfig.xml'
    & $SysmonExePath -accepteula -i $sysmonCfg
    Write-Ok 'Sysmon installed.'
}

Write-Step 'Configuring agent ports and starting WazuhSvc'
Set-WazuhAgentPorts -EventsPort $EventsPort -EnrollPort $EnrollPort
Restart-ServiceSafe -Name 'WazuhSvc'
Write-Ok "Windows endpoint enrolled to $ManagerIp (group: $AgentGroup)."
