[CmdletBinding()]
param(
    [ValidateRange(10, 180)]
    [int]$TimeoutSeconds = 60,

    [ValidateRange(1, 30)]
    [int]$RefreshDelaySeconds = 5
)

$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
    Write-Host "[discord-proton-refresh] $Message" -ForegroundColor Cyan
}

function Get-ProtonAppProcesses {
    Get-Process -ErrorAction SilentlyContinue | Where-Object {
        try {
            $_.Path -and
            $_.Path -like '*\Proton\VPN\*' -and
            $_.ProcessName -notmatch '(Service|WireGuard|Update|TlsVerify)'
        }
        catch {
            $false
        }
    }
}

function Get-PublicIp {
    try {
        return (Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 10).Trim()
    }
    catch {
        return $null
    }
}

function Find-ProtonExecutable {
    $running = Get-Process -Name 'ProtonVPN', 'ProtonVPN.Launcher' -ErrorAction SilentlyContinue |
        Where-Object { $_.Path } |
        Select-Object -First 1

    if ($running) { return $running.Path }

    $roots = @(
        (Join-Path $env:ProgramFiles 'Proton\VPN'),
        (Join-Path ${env:ProgramFiles(x86)} 'Proton\VPN'),
        (Join-Path $env:LOCALAPPDATA 'ProtonVPN')
    ) | Where-Object { $_ -and (Test-Path $_) }

    $executableNames = @('ProtonVPN.Launcher.exe', 'ProtonVPN.exe')
    foreach ($root in $roots) {
        foreach ($executableName in $executableNames) {
            $exe = Get-ChildItem -Path $root -Filter $executableName -File -Recurse -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1
            if ($exe) { return $exe.FullName }
        }
    }

    throw 'O executavel do Proton VPN nao foi encontrado. Instale ou abra o aplicativo oficial do Proton VPN.'
}

function Wait-ForIpChange {
    param(
        [AllowNull()][string]$PreviousIp,
        [int]$Timeout
    )

    $deadline = (Get-Date).AddSeconds($Timeout)
    do {
        Start-Sleep -Seconds 2
        $current = Get-PublicIp
        if ($current -and $PreviousIp -and $current -ne $PreviousIp) { return $current }
        if ($current -and -not $PreviousIp) { return $current }
    } while ((Get-Date) -lt $deadline)

    throw 'Nao foi possivel confirmar a troca do IP publico dentro do tempo limite.'
}

function Refresh-Discord {
    $discord = Get-Process -Name 'Discord' -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 } |
        Select-Object -First 1
    if (-not $discord) {
        throw 'Discord nao esta aberto ou a janela principal nao foi encontrada.'
    }

    $shell = New-Object -ComObject WScript.Shell
    if (-not $shell.AppActivate($discord.Id)) {
        throw 'Nao foi possivel ativar a janela do Discord.'
    }
    Start-Sleep -Milliseconds 500
    $shell.SendKeys('^r')

    # O Discord/Electron leva alguns segundos para reconstruir a janela.
    Start-Sleep -Seconds $RefreshDelaySeconds

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $ready = Get-Process -Name 'Discord' -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowHandle -ne 0 -and $_.Responding } |
            Select-Object -First 1
        if ($ready) { return }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)

    throw 'O Discord nao voltou a responder dentro do tempo limite.'
}

function Close-ProtonVpn {
    param(
        [string]$VpnIp,
        [int]$Timeout,
        [string]$LauncherPath
    )

    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes

    Start-Process -FilePath $LauncherPath

    $deadline = (Get-Date).AddSeconds($Timeout)
    $window = $null
    do {
        $gui = Get-Process -ErrorAction SilentlyContinue |
            Where-Object {
                $_.MainWindowHandle -ne 0 -and
                ($_.ProcessName -like 'Proton*' -or ($_.Path -and $_.Path -like '*\Proton\VPN\*'))
            } |
            Select-Object -First 1
        if ($gui) {
            $window = [System.Windows.Automation.AutomationElement]::FromHandle($gui.MainWindowHandle)
            break
        }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)

    if (-not $window) {
        throw 'Nao foi possivel abrir a janela do Proton para desconectar com seguranca.'
    }

    $elements = $window.FindAll(
        [System.Windows.Automation.TreeScope]::Descendants,
        [System.Windows.Automation.Condition]::TrueCondition
    )
    $disconnected = $false
    foreach ($element in $elements) {
        if ($element.Current.Name -match '^(Disconnect|Desconectar)$') {
            $pattern = $null
            if ($element.TryGetCurrentPattern(
                [System.Windows.Automation.InvokePattern]::Pattern,
                [ref]$pattern
            )) {
                $pattern.Invoke()
                $disconnected = $true
                break
            }
        }
    }

    if (-not $disconnected) {
        throw 'O botao Desconectar nao foi encontrado no Proton VPN.'
    }

    $deadline = (Get-Date).AddSeconds($Timeout)
    do {
        $currentIp = Get-PublicIp
        if ($currentIp -and $currentIp -ne $VpnIp) { break }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)

    if (-not $currentIp -or $currentIp -eq $VpnIp) {
        throw 'A VPN nao desconectou ou a internet nao voltou dentro do tempo limite.'
    }

    Get-Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.ProcessName -like 'Proton*' -and
            $_.ProcessName -notmatch '(Service|WireGuard|Update|TlsVerify)'
        } |
        Stop-Process -Force -ErrorAction SilentlyContinue

    $remaining = @(Get-Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.ProcessName -like 'Proton*' -and
            $_.ProcessName -notmatch '(Service|WireGuard|Update|TlsVerify)'
        })
    if ($remaining.Count -gt 0) {
        throw "Ainda existem processos do Proton abertos: $($remaining.ProcessName -join ', ')."
    }
}

$originalIp = Get-PublicIp
if (-not $originalIp) {
    throw 'Nao foi possivel consultar o IP publico antes de abrir a VPN.'
}
$protonExe = Find-ProtonExecutable

Write-Step 'Abrindo o Proton VPN...'
if (-not (Get-ProtonAppProcesses)) {
    Start-Process -FilePath $protonExe -WindowStyle Minimized
}

Write-Step 'Aguardando a conexao automatica da VPN...'
$vpnIp = Wait-ForIpChange -PreviousIp $originalIp -Timeout $TimeoutSeconds
Write-Step "VPN confirmada (IP: $vpnIp)."

Write-Step 'Atualizando o Discord com Ctrl+R...'
Refresh-Discord
Write-Step 'Discord voltou a responder.'

Write-Step 'Finalizando os processos do Proton VPN...'
Close-ProtonVpn -VpnIp $vpnIp -Timeout $TimeoutSeconds -LauncherPath $protonExe
Write-Step 'VPN desconectada, internet restaurada e interface do Proton encerrada.'
Write-Host 'Concluido.' -ForegroundColor Green
