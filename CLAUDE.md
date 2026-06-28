# scripts

A collection of **Bash provisioning / post-install scripts** for btc.jost AG infrastructure —
Debian/Ubuntu hosts and Proxmox/LXC containers. They bootstrap monitoring (Zabbix), time sync
(chrony) and 3CX servers. Designed to be piped straight into a root shell from GitHub raw URLs.

License: GPL-3.0 (see `LICENSE`); every script carries the GPL header. Author: Simon Gilli / btc.jost AG.

## Inventory

Standalone scripts (each runnable on its own):
- `3cx/post-install.sh` — after a fresh 3CX install on Debian: add Zabbix repo, install + configure
  `zabbix-agent2` (Server `192.168.72.5`), install chrony with Swiss NTP pool.
- `zabbix/install-sm-proxy.sh` — install a **SmartMonitoring proxy** (Zabbix 7.0) on Debian/Ubuntu.
  Interactive `whiptail` wizard (customer + location → hostname `<customer>-proxy-<location>`),
  installs `zabbix-proxy-sqlite3` + agent2 + chrony, generates a 256-byte PSK, prints it at the end.
  This is the most complete script; it does **not** use the `framework/` libs.
- `proxmox/post-install.sh` — **stub only** (TODO: configure chrony, install unattended-upgrades).

`framework/` — sourced Bash libraries (`.func`, `# shellcheck shell=bash`), an event-driven installer
mini-framework. **Note: incomplete / WIP** — they `source` from `https://.../main/misc/*.func`, but no
`misc/` directory exists in the repo, and `msg_error` / `msg_warn` / color vars are referenced but never
defined here. Treat as scaffolding, not finished.
- `framework/core.func` — `shell_check`, `root_check`, `set_std_mode` (VERBOSE→`STD`), `exit_script`.
- `framework/installer.func` — event-handler registry (`register_event_handler`, `installer_run` with
  install/update/remove modes and `configure`/`pre_*`/`*`/`post_*` events), `add_packages`, apt
  install/upgrade-with-retry helpers.
- `framework/script.func` — sources `installer.func`, `add_application` helper.

`installer/` — per-component installers built on the `framework/` event model (call
`register_event_handler` + `installer_run "$@"`):
- `installer/chrony.sh` — chrony installer with a `whiptail` NTP-source picker (Swiss pool or
  user-defined). Complete worked example of the framework.
- `installer/zabbix-agent2.sh` — Zabbix 8.0 agent2 (partial; defines a preinstall fn but then runs
  apt install at top level).
- `installer/zabbix-proxy.sh` — **stub** (sources installer.func, nothing else).

## How to run

Standalone scripts are meant to be piped into a root shell from GitHub raw, e.g.:
```bash
wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/3cx/post-install.sh | bash
wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/zabbix/install-sm-proxy.sh | bash
```
- **Bash only** (not POSIX sh) — `core.func`'s `shell_check` enforces it. Run **as root** (`root_check`).
- Targets **Debian/Ubuntu** (`apt`, reads `/etc/os-release`). Interactive scripts need `whiptail`.
- The `framework/`+`installer/` model expects the libs to be reachable at the `main/misc/` raw URL the
  scripts `source`; that path is not in this repo, so those scripts will not run as-is from a clean clone.

## Conventions

- Language: Bash. Indent 2 spaces, LF endings, UTF-8, final newline (`.editorconfig`).
  `*.sh` and `*.func` are forced to `eol=lf` (`.gitattributes`); `.vscode/*.json` uses CRLF + 4-space.
- Lint with **shellcheck** (libs start with `# shellcheck shell=bash`; inline `# shellcheck disable=...`
  where needed). Recommended VS Code extensions in `.vscode/extensions.json`: shellcheck, shell-format,
  shell-syntax, markdownlint, editorconfig.
- Naming: `<area>/<verb>-<thing>.sh`; framework hooks follow `<event>_<component>` (e.g. `install_chrony`).
- Every script begins with the standard GPL-3.0 header block.
