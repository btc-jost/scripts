# Helper scripts

A collection of Bash provisioning and post-install scripts for btc.jost AG infrastructure. They
bootstrap monitoring, time synchronization and telephony servers on Debian/Ubuntu hosts and
Proxmox/LXC containers. Most are designed to be piped straight into a root shell from GitHub.

Licensed under GPL-3.0 (see [`LICENSE`](LICENSE)).

## Repository layout

| Path | What it does |
| --- | --- |
| `3cx/post-install.sh` | Post-install for a fresh 3CX server on Debian: Zabbix agent 2 + chrony. |
| `zabbix/install-sm-proxy.sh` | Interactive installer for a SmartMonitoring (Zabbix 7.0) proxy. |
| `proxmox/post-install.sh` | Proxmox host post-install (stub / work in progress). |
| `framework/*.func` | Sourced Bash libraries: an event-driven installer mini-framework. |
| `installer/*.sh` | Per-component installers (chrony, Zabbix agent 2, Zabbix proxy) built on the framework. |

## Prerequisites

- A **Debian or Ubuntu** host (scripts use `apt` and read `/etc/os-release`).
- **Bash** as the running shell, executed **as root**.
- `wget` (used both to fetch the scripts and inside them).
- `whiptail` for the interactive scripts (`zabbix/install-sm-proxy.sh`, `installer/chrony.sh`).

## Usage

### 3CX

Post install script to be executed after a fresh 3CX installation on Debian.
Run the following command in a root shell:

```bash
wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/3cx/post-install.sh | bash
```

This adds the Zabbix repository, installs and configures `zabbix-agent2` (pointed at the
SmartMonitoring server), and installs chrony with the Swiss NTP pool.

### SmartMonitoring Proxy

Install script to provision a SmartMonitoring proxy on an Ubuntu/Debian host.
Run the following command in a root shell:

```bash
wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/zabbix/install-sm-proxy.sh | bash
```

A `whiptail` wizard prompts for a **customer name** and **location** (alphanumeric only); the proxy
hostname is built as `<customer>-proxy-<location>`. The script then installs `zabbix-proxy-sqlite3`,
`zabbix-agent2` and `chrony`, generates a 256-byte PSK at `/etc/zabbix/psk.key` (reused if present),
configures the proxy against `monitoring.smartcollab.ch`, and prints the hostname and PSK at the end so
they can be registered on the Zabbix server.

## Framework and component installers

`framework/` contains a small event-driven installer library, sourced (not executed) by the scripts in
`installer/`:

- `core.func` — shell/root checks, verbose mode, exit helper.
- `installer.func` — event-handler registry and `installer_run` driver with `install` / `update` /
  `remove` modes, plus apt install/upgrade-with-retry helpers.
- `script.func` — thin wrapper that sources `installer.func`.

A component installer registers handlers for lifecycle events (`configure`, `pre_install`, `install`,
`post_install`, and the corresponding `*_update` / `*_remove` events) and calls `installer_run "$@"`.
`installer/chrony.sh` is the most complete example: it adds the `chrony` package and offers a menu to
pick the Swiss NTP pool or enter custom NTP servers.

> Note: the framework and `installer/` scripts `source` their dependencies from a `main/misc/` path on
> GitHub raw that is not present in this repository, so they are not yet runnable from a clean clone.
> `proxmox/post-install.sh` and `installer/zabbix-proxy.sh` are stubs. Treat these as work in progress.

## Conventions

- Bash, 2-space indentation, LF line endings, UTF-8 (enforced via `.editorconfig` and `.gitattributes`).
- Scripts are linted with **shellcheck**; recommended VS Code extensions are listed in
  `.vscode/extensions.json`.
- Every script carries the standard GPL-3.0 header.
