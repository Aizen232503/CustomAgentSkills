# Windows Desktop and VS Code

## Proxy scope

Temporary PowerShell variables affect only that shell and child processes:

```powershell
$env:HTTP_PROXY  = "http://127.0.0.1:7897"
$env:HTTPS_PROXY = $env:HTTP_PROXY
$env:ALL_PROXY   = $env:HTTP_PROXY
$env:NO_PROXY    = "localhost,127.0.0.1,::1"
code .
```

User-scoped variables affect programs started afterward:

```powershell
[Environment]::SetEnvironmentVariable("HTTP_PROXY",  "http://127.0.0.1:7897", "User")
[Environment]::SetEnvironmentVariable("HTTPS_PROXY", "http://127.0.0.1:7897", "User")
[Environment]::SetEnvironmentVariable("ALL_PROXY",   "http://127.0.0.1:7897", "User")
[Environment]::SetEnvironmentVariable("NO_PROXY",    "localhost,127.0.0.1,::1", "User")
```

Never overwrite machine-scoped variables without explicit authorization. Restart Desktop and all `Code.exe` processes after changing persistent variables.

## Inspect safely

```powershell
'HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY' | ForEach-Object {
  $value = [Environment]::GetEnvironmentVariable($_, 'Process')
  "$_=" + $(if ($value) { 'SET' } else { 'NOT_SET' })
}
```

```powershell
Get-NetTCPConnection -State Listen -LocalPort 7897 |
  Select-Object LocalAddress,LocalPort,OwningProcess
```

`127.0.0.1:7897` works for Windows and WSL mirrored mode. NAT-mode WSL cannot reach a Windows service bound only to loopback.

## WebSocket override

Inspect `%USERPROFILE%\.codex\config.toml`. If present and not intentionally required, remove only:

```toml
supports_websockets = false
```

Back up the file and restart Codex.

## VS Code execution

The extension may be installed on Windows while launching Codex inside WSL:

```powershell
Get-ChildItem "$env:USERPROFILE\.vscode\extensions" -Directory |
  Where-Object Name -Match 'openai|codex|chatgpt'
```

Relevant setting:

```json
"chatgpt.runCodexInWindowsSubsystemForLinux": true
```

When true, Windows hosts the extension but WSL hosts the Codex execution backend. Reload VS Code after changing it. Agent mode availability may constrain native Windows execution.

## Symptom mapping

- `Reconnecting... waiting for network`: environment inheritance, WSL proxy, or WebSocket transport.
- `refresh token was revoked`: credentials, not connectivity.
- CLI works but extension fails: compare the backend environment with the successful shell.
- Desktop Chat works but Codex fails: do not assume they share proxy discovery or WebSocket endpoints.
