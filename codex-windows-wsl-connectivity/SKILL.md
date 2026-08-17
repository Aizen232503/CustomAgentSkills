---
name: codex-windows-wsl-connectivity
description: Diagnose and repair network and login problems for Codex CLI, Codex Desktop, and the Codex VS Code extension on Windows and WSL2. Use when a client cannot connect, waits for network, fails through a proxy, loses login state, reports a revoked token, or Windows and WSL behave differently.
---

# Codex CLI、Desktop、VS Code 排障

只处理两类问题：网络和登录。先确认故障发生在 CLI、Desktop，还是 VS Code 插件；VS Code 插件还要确认后端运行在 Windows 还是 WSL。

## 安全规则

- 修改配置前先备份。
- 不输出 `auth.json`、令牌、API Key 或代理凭据。
- 复制认证文件必须获得用户明确授权。
- 执行 `wsl --shutdown` 前提醒用户：它会关闭 WSL 终端和 Remote 会话。

## 1. 解决三端网络问题

### 先确认代理

依次检查：

1. 代理程序是否运行，监听地址、端口和协议是否正确。
2. 系统代理、TUN/PAC、路由规则和 OpenAI 域名规则是否放行。
3. 启动脚本、Shell 配置和环境变量是否覆盖了代理设置。
4. HTTPS 与 WebSocket 是否都能通过；普通网页能打开不代表 WebSocket 可用。

可先运行 `scripts/diagnose-codex-connectivity.ps1`；需要联网测试时再加 `-TestNetwork`。

### Codex CLI

确认 CLI 进程继承了正确的代理环境变量。只在当前终端设置的变量只影响该终端及其子进程。

### Codex Desktop

Desktop 尤其要检查 Windows 用户级环境变量：

- `HTTP_PROXY`
- `HTTPS_PROXY`
- `ALL_PROXY`
- `NO_PROXY=localhost,127.0.0.1,::1`

代理示例为 `http://127.0.0.1:7897`。修改用户级变量后，完全退出并重启 Desktop；旧进程不会自动获得新变量。

如果 `%USERPROFILE%\.codex\config.toml` 含有非必要的 `supports_websockets = false`，备份后只删除该覆盖项。

### VS Code 插件与 WSL

先确认插件后端是否在 WSL。若在 WSL，使用 `%USERPROFILE%\.wslconfig`：

```ini
[wsl2]
networkingMode=mirrored
dnsTunneling=true
autoProxy=true
```

应用配置时执行 `wsl --shutdown`。镜像模式下 Windows 的 `127.0.0.1:7897` 可直接从 WSL 访问；先依赖 `autoProxy=true`，不要再混入 NAT 网关脚本。只有自动代理未生效时，才在 WSL 内补充指向 `127.0.0.1:<port>` 的代理变量。

## 2. 解决三端登录问题

登录的本质是运行环境读取并刷新自己的认证文件：

| 运行环境 | 认证文件 |
|---|---|
| Windows CLI | `%USERPROFILE%\.codex\auth.json` |
| Codex Desktop | `%USERPROFILE%\.codex\auth.json` |
| VS Code 插件的 Windows 后端 | `%USERPROFILE%\.codex\auth.json` |
| WSL CLI 或插件的 WSL 后端 | `~/.codex/auth.json` |

重点：Windows 与 WSL 是两套文件。Windows 已登录不代表 WSL 内的后端已登录；插件安装在 Windows 也不代表其 Codex 后端运行在 Windows。

处理顺序：

1. 确认实际运行环境和对应的 `auth.json` 路径。
2. 文件缺失时在该环境重新登录。
3. 出现 `refresh token was revoked` 时重新登录；复制一个已失效文件没有作用。
4. 仅在用户明确要求同一账户同步时，将 Windows 文件复制到 WSL。
5. 复制前备份 WSL 文件，复制后设置 `~/.codex` 为 `700`、`auth.json` 为 `600`，只比较 SHA-256，不读取内容。
6. 重启 CLI、Desktop 或 VS Code 后验证。

模型不可用属于账户或认证方式权限问题，不要当成网络故障，也不要把“未登录”理解为可绕过权限。

## 最终验证

分别在 CLI、Desktop 和 VS Code 新建会话。若仍失败，只报告它属于代理、WSL 网络、认证文件或账户权限中的哪一层。
