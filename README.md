# Helper scripts

A collection of Bash provisioning and post-install scripts for btc.jost AG infrastructure. They
bootstrap monitoring, time synchronization and telephony servers on Debian/Ubuntu hosts and
Proxmox/LXC containers. Most are designed to be run straight from GitHub in a root shell.

Licensed under GPL-3.0 (see [`LICENSE`](LICENSE)).

## Prerequisites

- A **Debian or Ubuntu** host (scripts use `apt` and read `/etc/os-release`).
- **Bash** as the running shell, executed **as root**.
- `wget` (used both to fetch the scripts and inside them).
- `whiptail` for the interactive component/composite scripts (any that prompt, e.g.
  `zabbix/install-sm-proxy.sh`, `component/chrony.sh`, `component/zabbix-agent2.sh`,
  `component/zabbix-proxy.sh`). Unattended runs (`UNATTENDED=yes`) skip the prompts.

## Usage

Run these **as root** on Debian/Ubuntu. The `bash -c "$(wget …)"` form keeps stdin on your terminal
so the `whiptail` wizard works. Each script's default action is **install**; append `-- update` or
`-- remove` for the other modes (every command is listed per script below). `UNATTENDED=yes` takes the
declared defaults without prompting; `VERBOSE=yes` shows all command output. Interactive runs need
`whiptail`:

```bash
apt-get install -y whiptail
```

To run an unmerged branch end-to-end, fetch the script from that branch **and** point `FUNC_BASE_URL`
at the same branch (the script sources its `framework/*.func` libs from there; it defaults to `main`):

```bash
FUNC_BASE_URL=https://raw.githubusercontent.com/btc-jost/scripts/dev-framework bash -c "$(wget -O - https://raw.githubusercontent.com/btc-jost/scripts/dev-framework/3cx/post-install.sh)"
```

### Composites

Top-level installers that compose several components into one lifecycle (a single batched `apt`
install and one grouped service restart).

#### `3cx/post-install.sh`

Zabbix agent 2 (→ `192.168.72.5`) + chrony (Swiss NTP pool) for a fresh 3CX server; Zabbix repo 7.4.

Install:

```bash
bash -c "$(wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/3cx/post-install.sh)"
```

Update:

```bash
bash -c "$(wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/3cx/post-install.sh)" -- update
```

Remove:

```bash
bash -c "$(wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/3cx/post-install.sh)" -- remove
```

#### `zabbix/install-sm-proxy.sh`

SmartMonitoring proxy (Zabbix 7.0): `zabbix-proxy-sqlite3` + `zabbix-agent2` + chrony. The wizard asks
for a **customer name** and **location** (alphanumeric); the proxy hostname becomes
`<customer>-proxy-<location>`. It generates a 256-byte PSK at `/etc/zabbix/psk.key` (reused if
present), points the proxy at `monitoring.smartcollab.ch`, and prints the hostname and PSK at the end
so they can be registered on the Zabbix server.

Install:

```bash
bash -c "$(wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/zabbix/install-sm-proxy.sh)"
```

Update:

```bash
bash -c "$(wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/zabbix/install-sm-proxy.sh)" -- update
```

Remove:

```bash
bash -c "$(wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/zabbix/install-sm-proxy.sh)" -- remove
```

#### `proxmox/post-install.sh`

Zabbix agent 2 + chrony (Swiss NTP) + `unattended-upgrades` for a Proxmox host; Zabbix repo 7.0.

Install:

```bash
bash -c "$(wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/proxmox/post-install.sh)"
```

Update:

```bash
bash -c "$(wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/proxmox/post-install.sh)" -- update
```

Remove:

```bash
bash -c "$(wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/proxmox/post-install.sh)" -- remove
```

### Components

Reusable single-purpose units — run them standalone with the commands below, or pull them into a
composite with `include_component`.

#### `component/chrony.sh`

chrony with a menu to pick the Swiss NTP pool or enter custom servers.

Install:

```bash
bash -c "$(wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/component/chrony.sh)"
```

Update:

```bash
bash -c "$(wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/component/chrony.sh)" -- update
```

Remove:

```bash
bash -c "$(wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/component/chrony.sh)" -- remove
```

#### `component/zabbix-agent2.sh`

`zabbix-agent2`; prompts for the Zabbix server address and agent hostname.

Install:

```bash
bash -c "$(wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/component/zabbix-agent2.sh)"
```

Update:

```bash
bash -c "$(wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/component/zabbix-agent2.sh)" -- update
```

Remove:

```bash
bash -c "$(wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/component/zabbix-agent2.sh)" -- remove
```

#### `component/zabbix-proxy.sh`

`zabbix-proxy-sqlite3`; prompts for the Zabbix server address and proxy hostname.

Install:

```bash
bash -c "$(wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/component/zabbix-proxy.sh)"
```

Update:

```bash
bash -c "$(wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/component/zabbix-proxy.sh)" -- update
```

Remove:

```bash
bash -c "$(wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/component/zabbix-proxy.sh)" -- remove
```

## Reference

### Repository layout

| Path | What it does |
| --- | --- |
| `*/*.sh` | Composite installers — one per top-level folder (`3cx/`, `zabbix/`, `proxmox/`); see [Usage](#usage). |
| `component/*.sh` | Reusable component installers (chrony, Zabbix agent 2, Zabbix proxy) built on the framework; see [Usage](#usage). |
| `framework/*.func` | Sourced Bash libraries: an event-driven installer mini-framework. |

### Framework and component installers

`framework/` contains a small event-driven installer library, layered as single-purpose modules and
sourced (not executed) by the leaf scripts:

- `core.func` — colors/logging, shell/root checks, verbose mode, exit helper. Sourced by everything.
- `engine.func` — the installer engine: the event-handler registry, `add_packages`/`add_services`
  accumulators, batched apt/systemd default handlers, and the `installer_run` driver with
  `install` / `update` / `remove` modes.
- `prompt.func` — the declarative `whiptail` question wizard (omits any question whose variable is
  already set; `title=` sets a human-readable dialog title). When it shows any question it also adds a
  verbose toggle and a summary/confirm page, and numbers the steps by what's actually shown.
- `component-tools.func` — helpers shared by ≥2 components (`setup_zabbix_repo`). Single-use helpers
  stay inline in their script.
- `component.func` — entry point for the reusable units in `component/` (sources core + engine +
  prompt + component-tools).
- `composite.func` — entry point for the top-level composites (sources core + engine + prompt) and
  adds `include_component` for pulling components into one combined run.

A component is a flat script: it adds its package/service, registers questions for its config and
handlers for lifecycle events (`configure`, `pre_install`, `install`, `post_install`, and the
corresponding `*_update` / `*_remove` events), and ends with `installer_run "$@"`.
`component/chrony.sh` is the most complete example: it adds the `chrony` package and offers a menu to
pick the Swiss NTP pool or enter custom NTP servers. Composites pull it in with `include_component
chrony` (presetting `CHRONY__SOURCE=swiss` to skip the prompt).

> The leaf scripts `source` their framework dependencies from `${FUNC_BASE_URL:-…/main}/framework/…`.
> To run an unmerged branch end-to-end, export `FUNC_BASE_URL=…/<branch>`; for local development,
> pre-source the `framework/*.func` files so the load guards turn the remote `source` lines into
> no-ops (see `tests/harness.sh`).

### Conventions

- Bash, 2-space indentation, LF line endings, UTF-8 (enforced via `.editorconfig` and `.gitattributes`).
- Scripts are linted with **shellcheck**; recommended VS Code extensions are listed in
  `.vscode/extensions.json`.
- Every script carries the standard GPL-3.0 header.
