[CmdletBinding()]
param(
    [int]$ProxyPort = 7897,
    [switch]$TestNetwork
)

$ErrorActionPreference = 'Continue'

function Write-Section([string]$Name) {
    Write-Output ""
    Write-Output "=== $Name ==="
}

Write-Section 'Windows proxy environment'
foreach ($scope in 'Process', 'User', 'Machine') {
    foreach ($name in 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'NO_PROXY') {
        $value = [Environment]::GetEnvironmentVariable($name, $scope)
        $state = if ([string]::IsNullOrWhiteSpace($value)) { 'NOT_SET' } else { 'SET' }
        Write-Output "$scope $name=$state"
    }
}

Write-Section "Windows listener on port $ProxyPort"
$listeners = Get-NetTCPConnection -State Listen -LocalPort $ProxyPort -ErrorAction SilentlyContinue
if ($listeners) {
    $listeners | Select-Object LocalAddress, LocalPort, OwningProcess | Format-Table -AutoSize
} else {
    Write-Output 'NO_LISTENER'
}

Write-Section 'Codex config override'
$configPath = Join-Path $env:USERPROFILE '.codex\config.toml'
if (Test-Path -LiteralPath $configPath) {
    $override = Select-String -LiteralPath $configPath -Pattern '^\s*supports_websockets\s*=' -ErrorAction SilentlyContinue
    if ($override) { $override.Line } else { 'NO_WEBSOCKET_OVERRIDE' }
} else {
    'CONFIG_NOT_FOUND'
}

Write-Section 'Credential metadata'
$authPath = Join-Path $env:USERPROFILE '.codex\auth.json'
if (Test-Path -LiteralPath $authPath) {
    $auth = Get-Item -LiteralPath $authPath
    Write-Output "WINDOWS_AUTH_EXISTS size=$($auth.Length)"
    Write-Output "WINDOWS_AUTH_SHA256=$((Get-FileHash -Algorithm SHA256 -LiteralPath $authPath).Hash)"
} else {
    Write-Output 'WINDOWS_AUTH_MISSING'
}

Write-Section 'VS Code Codex extension'
$extensionRoots = @(
    (Join-Path $env:USERPROFILE '.vscode\extensions'),
    (Join-Path $env:USERPROFILE '.vscode-insiders\extensions')
)
foreach ($root in $extensionRoots) {
    Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
        Where-Object Name -Match '(?i)openai|codex|chatgpt' |
        Select-Object -ExpandProperty FullName
}

$settingsCandidates = @(
    (Join-Path $env:APPDATA 'Code\User\settings.json'),
    (Join-Path $env:APPDATA 'Code - Insiders\User\settings.json')
)
foreach ($settings in $settingsCandidates) {
    if (Test-Path -LiteralPath $settings) {
        $match = Select-String -LiteralPath $settings -Pattern '"chatgpt\.runCodexInWindowsSubsystemForLinux"\s*:\s*(true|false)' -ErrorAction SilentlyContinue
        if ($match) { Write-Output "$settings :: $($match.Matches[0].Value)" }
    }
}

Write-Section 'WSL status'
if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
    & wsl.exe --list --verbose
    & wsl.exe sh -lc 'printf "DISTRO=%s USER=%s HOME=%s SHELL=%s\n" "$WSL_DISTRO_NAME" "$USER" "$HOME" "$SHELL"; command -v wslinfo >/dev/null 2>&1 && printf "NETWORK_MODE=" && wslinfo --networking-mode || true; if [ -n "${HTTP_PROXY-}" ]; then echo HTTP_PROXY=SET; else echo HTTP_PROXY=NOT_SET; fi; if [ -n "${HTTPS_PROXY-}" ]; then echo HTTPS_PROXY=SET; else echo HTTPS_PROXY=NOT_SET; fi; if [ -n "${ALL_PROXY-}" ]; then echo ALL_PROXY=SET; else echo ALL_PROXY=NOT_SET; fi; if [ -n "${NO_PROXY-}" ]; then echo NO_PROXY=SET; else echo NO_PROXY=NOT_SET; fi; if [ -f "$HOME/.codex/auth.json" ]; then stat -c "WSL_AUTH_EXISTS size=%s mode=%a" "$HOME/.codex/auth.json"; printf "WSL_AUTH_SHA256="; sha256sum "$HOME/.codex/auth.json" | cut -d" " -f1; else echo WSL_AUTH_MISSING; fi; command -v codex || true'
} else {
    Write-Output 'WSL_NOT_INSTALLED'
}

if ($TestNetwork) {
    Write-Section 'Network test'
    try {
        $response = Invoke-WebRequest -Uri 'https://chatgpt.com' -Method Head -TimeoutSec 15 -UseBasicParsing
        Write-Output "WINDOWS_HTTPS_STATUS=$($response.StatusCode)"
    } catch {
        Write-Output "WINDOWS_HTTPS_FAILED=$($_.Exception.Message)"
    }

    if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
        & wsl.exe sh -lc 'curl -I --max-time 15 https://chatgpt.com 2>&1 | sed -n "1,8p"'
    }
}
