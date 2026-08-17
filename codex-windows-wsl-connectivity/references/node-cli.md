# Node, NVM, npm, pnpm, and Codex CLI

## Inventory before replacing Node

```powershell
node --version
npm --version
npm config get prefix
npm list --global --depth=0 --json
pnpm --version
pnpm list --global --depth=0 --json
```

Record exact global package versions. Project-local dependencies are separate.

## NVM for Windows

Avoid mixing a standalone Node MSI with NVM's symlink directory. Uninstall the MSI through Windows Installer before installing NVM. Do not manually delete `Program Files\nodejs` until installation state is understood.

NVM for Windows has no `nvm alias default`. `nvm use <version>` persists its symlink until changed.

Use exact versions when mirror major-version resolution is stale:

```powershell
nvm install 26.7.0
nvm use 26.7.0
```

Validate a mirror's `index.json` and exact Windows ZIP. An HTML error page saved as ZIP produces `zip: not a valid zip file`.

## Separate sources

NVM's Node mirror and npm's package registry are different:

```text
node_mirror: https://mirrors.ustc.edu.cn/node
npm_mirror: https://npmmirror.com/mirrors/npm
```

```powershell
npm config set registry https://registry.npmmirror.com
npm config get registry
```

## Package managers and Codex CLI

Node includes npm:

```powershell
npm install --global npm@latest pnpm@latest
npm install --global @openai/codex@latest
```

Verify:

```powershell
node --version
npm --version
pnpm --version
codex --version
npm list --global --depth=0
```

For direct WSL use, install a native Linux Codex CLI. A Windows npm shim mounted under `/mnt/c` can resolve `codex` but fail because Linux cannot find its Windows-managed Node runtime.
