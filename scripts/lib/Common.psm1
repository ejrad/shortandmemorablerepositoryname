function Write-Step {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Test-TcpPort {
    param(
        [Parameter(Mandatory)][string]$TargetHost,
        [Parameter(Mandatory)][int]$Port
    )
    $res = Test-NetConnection -ComputerName $TargetHost -Port $Port -WarningAction SilentlyContinue
    if ($res.TcpTestSucceeded) {
        Write-Ok "Reachable: ${TargetHost}:${Port}"
        return $true
    }
    Write-Warning "Cannot reach ${TargetHost}:${Port} right now (firewall, route, or service down)."
    return $false
}

function Set-FirewallAllowRule {
    param(
        [Parameter(Mandatory)][string]$DisplayName,
        [Parameter(Mandatory)][int]$Port,
        [string[]]$RemoteAddress = @('Any')
    )
    Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName $DisplayName `
        -Direction Inbound -Action Allow -Protocol TCP `
        -LocalPort $Port -RemoteAddress $RemoteAddress `
        -Profile Any | Out-Null
    Write-Ok "Firewall rule '$DisplayName' (TCP/$Port) configured."
}

function Restart-ServiceSafe {
    param([Parameter(Mandatory)][string]$Name)
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) { throw "Service '$Name' not found." }
    if ($svc.Status -eq 'Running') { Restart-Service -Name $Name -Force }
    else { Start-Service -Name $Name }
    Start-Sleep -Seconds 3
    $status = (Get-Service -Name $Name).Status
    if ($status -ne 'Running') { throw "Service '$Name' status is $status." }
    Write-Ok "Service '$Name' is running."
}

function Set-WazuhAgentPorts {
    param(
        [string]$ConfigPath = 'C:\Program Files (x86)\ossec-agent\ossec.conf',
        [int]$EventsPort = 51514,
        [int]$EnrollPort = 51515
    )
    if (-not (Test-Path $ConfigPath)) { throw "Wazuh agent config not found: $ConfigPath" }
    [xml]$xml = Get-Content -Path $ConfigPath -Raw
    $client = $xml.ossec_config.client
    if ($client.server) {
        if (-not $client.server.port) {
            $p = $xml.CreateElement('port')
            $client.server.AppendChild($p) | Out-Null
        }
        $client.server.port = [string]$EventsPort
    }
    if (-not $client.enrollment) {
        $enr = $xml.CreateElement('enrollment')
        $client.AppendChild($enr) | Out-Null
    }
    if (-not $client.enrollment.port) {
        $ep = $xml.CreateElement('port')
        $client.enrollment.AppendChild($ep) | Out-Null
    }
    $client.enrollment.port = [string]$EnrollPort
    $xml.Save($ConfigPath)
    Write-Ok "Configured Wazuh agent ports (events=$EventsPort, enroll=$EnrollPort)."
}

Export-ModuleMember -Function Write-Step, Write-Ok, Test-TcpPort, Set-FirewallAllowRule, Restart-ServiceSafe, Set-WazuhAgentPorts
