# Sing-box-EV

[中文文档](./README.md) | English

Sing-box-EV is a Linux-focused management script project for `sing-box`.
It provides:

- One-click install and update
- TUI menu + CLI commands
- Multi-protocol node management (including Reality / AnyTLS / CFtunnel)
- Subscription export
- Basic ops automation (service management, log cleanup, cron tasks)

This file is written for developers who want to quickly understand and contribute.

---

## 1. Highlights

- 20+ protocols and combinations
- Menu-driven and command-driven workflows
- Reality domain pool with health checks, weighted selection, and region preference
- Cloudflare Tunnel support for no-public-IP scenarios

---

## 2. Runtime Requirements

### 2.1 Server Runtime

- Ubuntu 20.04+
- Debian 11+
- CentOS 7+
- Architecture: `x86_64` / `arm64`
- Root user required

### 2.2 Development Environment

- Any environment with `bash` (Linux/macOS/WSL recommended)
- Recommended tools:
  - `shellcheck`
  - `shfmt`
- Optional:
  - A test VPS for real integration checks

---

## 3. Install (User Side)

```bash
bash <(curl -s -L https://raw.githubusercontent.com/LuoPoJunZi/sing-box-ev/main/install.sh)
```

Fallback:

```bash
bash <(curl -s -L https://github.com/LuoPoJunZi/sing-box-ev/raw/main/install.sh)
```

Common commands:

```bash
sb
sb help
sb version
sb status
```

---

## 4. CLI Quick Reference

| Command | Description |
| --- | --- |
| `sb a <protocol>` | Add a node, e.g. `sb a reality` |
| `sb i <name>` | Show node details |
| `sb c <name>` | Change node settings |
| `sb d <name>` | Delete node |
| `sb sub` | Generate subscription |
| `sb all` | Print all node URLs |
| `sb log` | Tail runtime logs |
| `sb update` | Update core/script |
| `sb domain list` | List Reality domain pool |
| `sb domain add <domain> [weight] [region]` | Add domain |
| `sb domain del <domain>` | Remove/disable domain |
| `sb domain test [region] [domain]` | Health check |
| `sb domain pick [region]` | Preview selected domain |

---

## 5. Repository Layout

```text
.
├─ install.sh
├─ sing-box.sh
├─ src
│  ├─ init.sh
│  ├─ core.sh
│  ├─ utils.sh
│  ├─ help.sh
│  ├─ caddy.sh
│  ├─ import.sh
│  └─ core
│     ├─ 00_env.sh
│     ├─ 10_ui.sh
│     ├─ 20_validate.sh
│     ├─ 25_domain.sh
│     ├─ 30_runtime.sh
│     ├─ 40_node_query.sh
│     ├─ 50_node_write.sh
│     ├─ 60_sub.sh
│     └─ 70_admin.sh
├─ scripts
│  ├─ lint.sh
│  ├─ smoke.sh
│  └─ smoke-reality.sh
└─ .github/workflows
   ├─ lint.yml
   └─ release.yml
```

---

## 6. Module Responsibilities

- `00_env.sh`: shared constants and defaults
- `10_ui.sh`: output helpers
- `20_validate.sh`: input/port validation
- `25_domain.sh`: Reality domain pool and strategy
- `30_runtime.sh`: service/cron operations
- `40_node_query.sh`: read/query/display/URL
- `50_node_write.sh`: create/change/delete
- `60_sub.sh`: subscription generation
- `70_admin.sh`: CLI/menu dispatch

---

## 7. Request Flow

For `sb add reality`:

1. `sing-box.sh` receives CLI args
2. `src/init.sh` initializes environment
3. `src/core.sh` loads modules and wrappers
4. `src/core/70_admin.sh` dispatches command
5. `src/core/50_node_write.sh` writes config
6. `src/core/40_node_query.sh` renders info and URL

Rule of thumb:

- Dispatch in `70_admin.sh`
- Write logic in `50_node_write.sh`
- Read/display logic in `40_node_query.sh`

---

## 8. Developer Onboarding (First 30 Minutes)

1. Read:
   - `README.md`
   - `CONTRIBUTING.md`
   - `src/core/README.md`
2. Start with dispatch file:
   - `src/core/70_admin.sh`
3. Then jump to your target module (`40` / `50` / `25` etc.)

### First feature change checklist

- Update command routing (`70_admin.sh`) if needed
- Update write path (`50_node_write.sh`)
- Update read/display path (`40_node_query.sh`)
- Update defaults (`00_env.sh`) if needed
- Update help docs (`src/help.sh`)

---

## 9. Quality Checks

```bash
bash scripts/lint.sh
bash scripts/smoke.sh
```

Optional integration check:

```bash
bash scripts/smoke-reality.sh
```

Note: `smoke-reality.sh` creates and removes test Reality nodes. Run it on a test host.

---

## 10. Reality Domain Pool Notes

`src/core/25_domain.sh` includes:

- Pool merge (built-in + custom)
- Weighted random selection
- Region preference (`us` / `eu` / `apac` / `global`)
- Health checks and cache
- Recent-domain avoidance

Persistent files are stored under `$is_sh_dir` (usually `/etc/sing-box/sh`).

---

## 11. CI and Release

### CI

- Workflow: `.github/workflows/lint.yml`
- Runs `shellcheck` and `shfmt`

### Release

- Workflow: `.github/workflows/release.yml`
- Version source: `is_sh_ver` in `src/init.sh`
- Creates release when tag is new

Before release:

1. bump `is_sh_ver`
2. run local checks
3. keep README/help in sync with behavior

---

## 12. Common Tasks: Where to Edit

### Add a command

- `src/core/70_admin.sh`
- `src/help.sh`
- optional wrapper in `src/core.sh`

### Add/change protocol fields

- defaults: `src/core/00_env.sh`
- write path: `src/core/50_node_write.sh`
- display/URL path: `src/core/40_node_query.sh`
- validation: `src/core/20_validate.sh`

### Runtime behavior

- service/cron control: `src/core/30_runtime.sh`
- service template/download: `src/utils.sh`

---

## 13. Troubleshooting (Dev)

- Command not visible: check `70_admin.sh` routing and `core.sh` wrapper
- URL mismatch with config: check both `50_node_write.sh` and `40_node_query.sh`
- Lint passes but runtime fails: verify runtime deps (`jq`, `openssl`, `timeout`) on real Linux host

---

## 14. Contributing & License

- Contribution guide: [CONTRIBUTING.md](./CONTRIBUTING.md)
- License: GPL v3
- Core upstream: `SagerNet/sing-box`
