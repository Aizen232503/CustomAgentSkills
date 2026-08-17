# WSL2 Networking and Authentication

## Inspect first

```powershell
wsl.exe --list --verbose
wsl.exe sh -lc 'printf "USER=%s HOME=%s SHELL=%s DISTRO=%s\n" "$USER" "$HOME" "$SHELL" "$WSL_DISTRO_NAME"; wslinfo --networking-mode; ip route show default'
```

## Mirrored mode

Preserve unrelated `.wslconfig` values:

```ini
[wsl2]
networkingMode=mirrored
dnsTunneling=true
autoProxy=true
```

Apply with `wsl --shutdown`, warning first. In `~/.bashrc`:

```bash
export HTTP_PROXY="http://127.0.0.1:7897"
export HTTPS_PROXY="$HTTP_PROXY"
export ALL_PROXY="$HTTP_PROXY"
export http_proxy="$HTTP_PROXY"
export https_proxy="$HTTPS_PROXY"
export all_proxy="$ALL_PROXY"
export NO_PROXY="localhost,127.0.0.1,::1"
export no_proxy="$NO_PROXY"
```

## NAT mode

Use a dynamic gateway:

```bash
_windows_host="$(ip route show default 2>/dev/null | awk 'NR==1 {print $3}')"
if [ -n "$_windows_host" ]; then
  export HTTP_PROXY="http://${_windows_host}:7897"
  export HTTPS_PROXY="$HTTP_PROXY"
  export ALL_PROXY="$HTTP_PROXY"
fi
unset _windows_host
```

The Windows proxy must enable LAN access and listen on `0.0.0.0` or the WSL-facing interface.

## Verification

```bash
source ~/.bashrc
wslinfo --networking-mode
env | grep -E '^(HTTP_PROXY|HTTPS_PROXY|ALL_PROXY|NO_PROXY)='
curl -I --max-time 15 https://chatgpt.com
```

`HTTP/1.1 200 Connection established` followed by a Cloudflare 403 challenge proves transport works.

## Synchronize the same login state

Only with explicit authorization, copy Windows credentials into the selected WSL user's home. Do not print file contents:

```powershell
$windowsAuth = "$env:USERPROFILE\.codex\auth.json"
Get-FileHash -Algorithm SHA256 -LiteralPath $windowsAuth
wsl.exe sh -lc 'mkdir -p "$HOME/.codex"; chmod 700 "$HOME/.codex"; if [ -f "$HOME/.codex/auth.json" ]; then cp "$HOME/.codex/auth.json" "$HOME/.codex/auth.json.backup.$(date +%Y%m%d%H%M%S)"; fi; install -m 600 /mnt/c/Users/REPLACE_USER/.codex/auth.json "$HOME/.codex/auth.json"; sha256sum "$HOME/.codex/auth.json"'
```

Replace `REPLACE_USER` with the verified Windows profile directory. Compare hashes only. If the source refresh token is revoked too, copying cannot repair it; log out and sign in again.
