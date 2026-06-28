# Helper scripts

A collection of Bash provisioning and post-install scripts for btc.jost AG infrastructure. They
bootstrap monitoring, time synchronization and telephony servers on Debian/Ubuntu hosts and
Proxmox/LXC containers. Most are designed to be run straight from GitHub in a root shell.

Licensed under GPL-3.0 (see [`LICENSE`](LICENSE)).

## Repository layout

| Path | What it does |
| --- | --- |
| `3cx/post-install.sh` | Post-install for a fresh 3CX server on Debian: Zabbix agent 2 + chrony. |
| `zabbix/install-sm-proxy.sh` | Interactive installer for a SmartMonitoring (Zabbix 7.0) proxy. |
| `proxmox/post-install.sh` | Proxmox host post-install: chrony (Swiss NTP) + unattended-upgrades. |
| `framework/*.func` | Sourced Bash libraries: an event-driven installer mini-framework. |
| `component/*.sh` | Reusable component installers (chrony, Zabbix agent 2, Zabbix proxy) built on the framework. |

## Prerequisites

- A **Debian or Ubuntu** host (scripts use `apt` and read `/etc/os-release`).
- **Bash** as the running shell, executed **as root**.
- `wget` (used both to fetch the scripts and inside them).
- `whiptail` for the interactive component/composite scripts (any that prompt, e.g.
  `zabbix/install-sm-proxy.sh`, `component/chrony.sh`, `component/zabbix-agent2.sh`,
  `component/zabbix-proxy.sh`). Unattended runs (`UNATTENDED=yes`) skip the prompts.

## Usage

Run every script **as root** on a Debian/Ubuntu host, fetched straight from GitHub.
Using `bash -c "$(wget …)"` keeps stdin on your terminal so the `whiptail` wizard works.
The default action is **install**; pass `update` or `remove` as an argument after `--`.
Replace `<path>` with one of the scripts from the [Composites](#composites) or
[Components](#components) tables below.

Install (default):

```bash
bash -c "$(wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/<path>)"
```

Update:

```bash
bash -c "$(wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/<path>)" -- update
```

Remove:

```bash
bash -c "$(wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/<path>)" -- remove
```

Set `UNATTENDED=yes` to take the declared defaults without prompting, and `VERBOSE=yes`
to show all command output. Interactive runs need `whiptail`:

```bash
apt-get install -y whiptail
```

### Composites

Top-level installers that compose several components into one lifecycle (a single
batched `apt` install and one grouped service restart).

| Path | Installs / configures |
| --- | --- |
| `3cx/post-install.sh` | Post-install for a fresh 3CX server: `zabbix-agent2` (→ `192.168.72.5`) + chrony (Swiss NTP pool), Zabbix repo 7.4. |
| `zabbix/install-sm-proxy.sh` | SmartMonitoring proxy (Zabbix 7.0): `zabbix-proxy-sqlite3` + `zabbix-agent2` + chrony, with a customer/location wizard, PSK and Swiss NTP. |
| `proxmox/post-install.sh` | Proxmox host post-install: `zabbix-agent2` + chrony (Swiss NTP) + `unattended-upgrades`, Zabbix repo 7.0. |

**SmartMonitoring Proxy** — the wizard asks for a **customer name** and **location**
(alphanumeric only); the proxy hostname is built as `<customer>-proxy-<location>`. It
generates a 256-byte PSK at `/etc/zabbix/psk.key` (reused if present), points the proxy
at `monitoring.smartcollab.ch`, and prints the hostname and PSK at the end so they can
be registered on the Zabbix server.

### Components

Reusable single-purpose units. Run them standalone with the commands above, or pull
them into a composite with `include_component`.

| Path | Installs / configures |
| --- | --- |
| `component/chrony.sh` | chrony; menu to pick the Swiss NTP pool or enter custom servers. |
| `component/zabbix-agent2.sh` | `zabbix-agent2`; prompts for the Zabbix server address and agent hostname. |
| `component/zabbix-proxy.sh` | `zabbix-proxy-sqlite3`; prompts for the Zabbix server address and proxy hostname. |

## Framework and component installers

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

## Conventions

- Bash, 2-space indentation, LF line endings, UTF-8 (enforced via `.editorconfig` and `.gitattributes`).
- Scripts are linted with **shellcheck**; recommended VS Code extensions are listed in
  `.vscode/extensions.json`.
- Every script carries the standard GPL-3.0 header.
