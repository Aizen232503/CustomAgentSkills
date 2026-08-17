---
name: codex-windows-wsl-connectivity
description: Diagnose and repair login, authentication, credential sharing, proxy, HTTPS, and WebSocket problems across Codex CLI, Codex Desktop, and the Codex VS Code extension on Windows and WSL2. Use when the three Codex clients behave differently, Desktop or the extension waits for network, CLI works only in one terminal, VS Code launches its backend in WSL, proxy variables are missing or inherited incorrectly, refresh tokens are revoked or stale, Windows and WSL login states diverge, a model is unavailable for the current authentication mode, or Node/NVM-based Codex CLI installation needs recovery.
---

# Codex Three-Client Login, Authentication, and Networking

Restore Codex CLI, Desktop, and VS Code extension access without conflating their process environments, authentication files, network stacks, or optional WSL execution backend.

## Scope

Treat the problem as three client surfaces and three independent layers:

| Client surface | Login and authentication | Network and proxy |
|---|---|---|
| Codex CLI | Determine whether it uses ChatGPT OAuth or an API key and which `auth.json` its runtime reads | Inspect the launching shell's inherited proxy variables and CLI runtime location |
| Codex Desktop | Verify its Windows login state and user credential file | Inspect Windows user environment variables, HTTPS, and secure WebSocket transport |
| Codex VS Code extension | Determine whether the extension backend runs on Windows or in WSL and which credential file it reads | Inspect VS Code process inheritance, extension settings, WSL networking mode, and proxy reachability |

Always separate these layers:

1. **Login state:** whether the user has signed in or supplied an API key.
2. **Credential validity:** whether the access/refresh credential is present, current, and permitted to use the requested model.
3. **Network transport:** whether DNS, HTTPS, proxying, and WebSocket upgrades work in the actual runtime environment.

A successful result on one client or layer does not prove the other clients or layers work.

## Safety rules

- Diagnose before mutating.
- Never print `auth.json`, API keys, cookies, proxy credentials, or full environment-variable values containing secrets.
- Before replacing `.wslconfig`, `.bashrc`, `config.toml`, VS Code settings, or `auth.json`, create a timestamped backup.
- Treat copying `auth.json` as credential transfer. Do it only when the user explicitly authorizes synchronizing the same account between their Windows and WSL environments.
- Hash credential files to verify equality; never inspect their contents.
- Do not disable TLS verification or certificate validation to work around connectivity failures.
- Warn that `wsl --shutdown` terminates WSL terminals and VS Code Remote sessions.

## Core workflow

### 1. Identify the failing surface

Classify the failure:

- Desktop/Chat works but Codex does not: suspect a separate Codex network stack and missing proxy environment variables.
- CLI works only in the terminal where variables were set: suspect process inheritance or variable scope.
- VS Code shows `Reconnecting... waiting for network`: inspect whether Windows extension settings launch Codex inside WSL.
- `refresh token was revoked`: fix authentication after connectivity; do not call it a proxy error.
- `model is not supported with a ChatGPT account`: distinguish ChatGPT OAuth from API-key authentication; logged-out is not an access mode.

Run `scripts/diagnose-codex-connectivity.ps1` first. Add `-TestNetwork` only when an external request is appropriate.

### 2. Map execution boundaries

| Surface | Typical environment | Credential path |
|---|---|---|
| Codex Desktop | Windows app plus child processes | `%USERPROFILE%\.codex\auth.json` |
| Codex CLI on Windows | Launching Windows shell | `%USERPROFILE%\.codex\auth.json` |
| VS Code Codex extension | Extension installed on Windows | Windows extension directory |
| Codex launched by VS Code in WSL | Linux process inside selected distro | `~/.codex/auth.json` |
| Native Codex CLI in WSL | Linux shell | `~/.codex/auth.json` |

Do not infer runtime location from the extension installation directory alone. Inspect `chatgpt.runCodexInWindowsSubsystemForLinux` and the actual WSL files/processes.

### 3. Repair Windows connectivity

Read [references/windows-and-vscode.md](references/windows-and-vscode.md) when Windows Desktop, CLI, or VS Code is involved.

Use `HTTP_PROXY`, `HTTPS_PROXY`, and `ALL_PROXY` when the Codex component ignores the Windows system proxy. Add `NO_PROXY` for loopback destinations. Restart the parent application after changing user-scoped variables because existing processes retain their old environment.

If `config.toml` contains `supports_websockets = false`, remove only that override unless the user explicitly needs HTTP-only fallback. Verify secure WebSocket upgrades through the proxy rather than assuming ordinary HTTPS proves WebSocket support.

### 4. Select a WSL2 network strategy

Read [references/wsl-and-auth.md](references/wsl-and-auth.md) before editing `.wslconfig`, shell startup files, or credentials.

Prefer mirrored mode on supported Windows 11 systems when the Windows proxy listens only on `127.0.0.1`:

```ini
[wsl2]
networkingMode=mirrored
dnsTunneling=true
autoProxy=true
```

Then set WSL proxy variables to `http://127.0.0.1:<port>`.

For NAT mode, resolve the Windows host gateway dynamically from `ip route show default`; never hardcode the gateway. NAT requires the Windows proxy to listen on a LAN-accessible address such as `0.0.0.0`, plus an appropriate firewall rule.

### 5. Repair authentication separately

For a revoked refresh token, first try logout/sign-in. If Windows is authenticated and the same user's WSL credential is missing or stale, synchronize only with explicit authorization:

1. Confirm both paths.
2. Back up the WSL file when present.
3. Copy without displaying content.
4. Set `~/.codex` to `700` and `auth.json` to `600`.
5. Compare SHA-256 hashes.
6. Reload VS Code or restart the WSL CLI.

Do not claim an extension is installed in WSL merely because its backend reads WSL credentials.

### 6. Recover CLI tooling only when needed

Read [references/node-cli.md](references/node-cli.md) for NVM for Windows, Node mirrors, npm registry configuration, global package inventory, or Codex CLI installation.

Prefer a native WSL Codex installation for direct WSL use. A Windows npm shim visible under `/mnt/c/...` is not a native WSL installation and may fail with `exec: node: not found`.

### 7. Verify the outcome

Verify in layers:

1. Proxy listener exists on the expected Windows address and port.
2. The target process sees the expected variables.
3. WSL reports the expected networking mode.
4. HTTPS reaches the service through the proxy. A Cloudflare challenge response still proves transport connectivity.
5. Codex authentication status succeeds without printing credentials.
6. A new Codex conversation streams without reconnect loops.

Report which layer failed. Do not equate an HTTP 403 challenge with a dead proxy.
