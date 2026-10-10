#Requires -RunAsAdministrator
$ErrorActionPreference = 'Continue'

# ===== CONFIG =====
$Server  = '157.245.129.235:8008'
$TLS     = 'false'
$Secret  = '4K4dGAz8LPQSeedbcK9rl2MWGHbRJoFW'
$Version = 'v2.3.5'
# ==================

$logPath = 'C:\nezha-install.log'
function Log($msg) {
    Write-Host $msg
    Add-Content -Path $logPath -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $msg" -Encoding ASCII
}

"===== Nezha install $(Get-Date) =====" | Out-File $logPath -Encoding ASCII

Log "Server  : $Server"
Log "TLS     : $TLS"
Log "Version : $Version"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ---- 1. Clean ----
Log '[1/5] Cleaning previous install...'
Get-Service -Name '*nezha*' -ErrorAction SilentlyContinue | Stop-Service -Force -ErrorAction SilentlyContinue
Get-Process -Name 'nezha-agent' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep 2
sc.exe delete nezha-agent 2>&1 | Out-Null
Remove-Item 'C:\nezha' -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item 'C:\nezha.zip' -Force -ErrorAction SilentlyContinue
New-Item -Path 'C:\nezha' -ItemType Directory -Force | Out-Null

# ---- 2. Download ----
Log '[2/5] Downloading agent...'
$url = "https://github.com/nezhahq/agent/releases/download/$Version/nezha-agent_windows_amd64.zip"
try {
    Invoke-WebRequest -Uri $url -OutFile 'C:\nezha.zip' -UseBasicParsing
    Log '     [OK] Downloaded'
} catch {
    Log "     [X] Download failed: $($_.Exception.Message)"
    Read-Host 'Press Enter to exit'
    exit 1
}

# ---- 3. Extract ----
Log '[3/5] Extracting...'
Expand-Archive -Path 'C:\nezha.zip' -DestinationPath 'C:\nezha' -Force
Remove-Item 'C:\nezha.zip' -Force

# ---- 4. Config ----
Log '[4/5] Writing config.yml...'
$yaml = @"
client_secret: $Secret
debug: false
disable_auto_update: false
disable_command_execute: false
disable_force_update: false
disable_nat: false
disable_send_query: false
gpu: false
insecure_tls: true
ip_report_period: 1800
report_delay: 4
server: "$Server"
skip_connection_count: false
skip_procs_count: false
temperature: false
tls: $TLS
use_gitee_to_upgrade: false
use_ipv6_country_code: false
uuid: 
"@
[System.IO.File]::WriteAllText('C:\nezha\config.yml', $yaml, [System.Text.Encoding]::ASCII)

Log '     Config contents:'
Get-Content 'C:\nezha\config.yml' | ForEach-Object { Log "     | $_" }

# ---- 5. Service ----
Log '[5/5] Installing service...'
sc.exe create nezha-agent binPath= "C:\nezha\nezha-agent.exe" start= auto DisplayName= "Nezha Agent" 2>&1 | ForEach-Object { Log "     $_" }
sc.exe description nezha-agent "Nezha monitoring agent" 2>&1 | Out-Null
sc.exe start nezha-agent 2>&1 | ForEach-Object { Log "     $_" }
Start-Sleep 4

$svc = Get-Service 'nezha-agent' -ErrorAction SilentlyContinue
if ($svc) {
    Log "     Service status: $($svc.Status)"
} else {
    Log '     [X] Service not found'
}

# ---- Foreground test if service failed ----
if (-not $svc -or $svc.Status -ne 'Running') {
    Log '[!] Service not running. Testing in foreground for 10 seconds...'
    Set-Location 'C:\nezha'
    $job = Start-Job -ScriptBlock { Set-Location 'C:\nezha'; & '.\nezha-agent.exe' 2>&1 }
    Start-Sleep 10
    Receive-Job $job | ForEach-Object { Log "     $_" }
    Stop-Job $job -ErrorAction SilentlyContinue
    Remove-Job $job -Force -ErrorAction SilentlyContinue
}

Log ''
Log '--- Last 20 log lines from agent ---'
Get-Content 'C:\nezha\nezha-agent.log' -Tail 20 -ErrorAction SilentlyContinue | ForEach-Object { Log "     $_" }

Log ''
Log '===== Done ====='
Read-Host 'Press Enter to close'
