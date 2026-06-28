# Testing & WSL2 continuation guide

This note captures everything needed to continue developing/testing the installer framework on a
real Linux box (WSL2 Ubuntu / a throwaway LXC). The framework is feature-complete and passes the
stubbed dry-run harness + shellcheck; the remaining proof is **real** `apt`/`whiptail`/`systemd`
execution. Prefer a throwaway LXC/VM for real installs, and use `remove` mode to clean up after.

## What exists

Event-driven Bash installer framework under `framework/` (layered: `core` → `engine` → entry
points `component.func` / `composite.func`, plus `prompt` and the `*-tools` helpers), reusable
component units under `component/`, and composites (`zabbix/install-sm-proxy.sh`,
`3cx/post-install.sh`, `proxmox/post-install.sh`). See the repo `CLAUDE.md` for the full
architecture. Key ideas:

- A **component** sources `component.func` and is a **flat** script with a fixed section order:
  contract vars → func calls (`add_packages`/`add_services` + `register_question`/
  `register_event_handler`, run at source time) → plain funcs → event funcs (handler defs) →
  `installer_run "$@"`. No `<slug>_register()` wrapper and no `_COMPOSING` guard — the engine no-ops
  `installer_run` when `_COMPOSING` is set. A question whose var is already set (composite preset,
  env, or a `configure` handler) is omitted by the wizard.
- **Composition:** a composite sources `composite.func`, sets a component's contract vars **first**,
  calls `include_component <slug>` (sources a sibling under `_COMPOSING`), adds its own steps, and
  runs ONE `installer_run`. The core then does one batched `apt install` and one grouped
  `systemctl enable/restart`.
- **Prompts** are declarative (`register_question`), rendered by a multi-step whiptail wizard, with
  unattended fallback to declared defaults.

## Local dry-run harness (no root, no Debian)

```bash
bash tests/harness.sh <script> [mode]
SM_PROXY__CUSTOMER=acme SM_PROXY__LOCATION=zrh bash tests/harness.sh zabbix/install-sm-proxy.sh install
```

Stubs `apt-get`/`systemctl`/`dpkg`/`wget`/`chronyc`/`openssl` and `setup_zabbix_repo`, redirects
config writes under a temp dir, and asserts the batched install + grouped restart + repo
idempotency. It uses the real `run_questions` (unattended), so it also exercises the omit-when-set
behaviour. Good for checking event ordering and composition; it
does **not** prove the real package install works.

Quick syntax sweep:
```bash
for f in framework/*.func component/*.sh zabbix/*.sh 3cx/*.sh proxmox/*.sh tests/*.sh; do bash -n "$f"; done
```

## WSL2 / LXC real-test checklist

Prereqs: Debian/Ubuntu, root, `whiptail` installed (`apt-get install -y whiptail`), `shellcheck`
for linting (`apt-get install -y shellcheck`).

1. **Lint:** `shellcheck framework/*.func component/*.sh zabbix/*.sh 3cx/*.sh proxmox/*.sh tests/*.sh`
   (libs carry `# shellcheck shell=bash`). **Status (shellcheck 0.11.0):** clean after the
   flatten/re-layer/rename refactor.
2. **Branch sourcing:** these scripts source siblings from `${FUNC_BASE_URL}/framework|component/...`.
   This branch is `dev-framework`. To test the pushed branch end-to-end via the canonical pipe:
   ```bash
   export FUNC_BASE_URL=https://raw.githubusercontent.com/btc-jost/scripts/dev-framework
   wget -O - "$FUNC_BASE_URL/component/chrony.sh" | bash -s install
   ```
   To test the working tree directly without pushing, run files in place:
   `sudo bash component/chrony.sh install` (it still pulls libs from `FUNC_BASE_URL` unless you set
   `COMPONENT_LOCAL_DIR` and pre-source the local `framework/*.func`).
3. **Standalone components** (`bash <script> install`, also `update` / `remove`):
   - `component/chrony.sh` — wizard picks Swiss pool vs custom; confirm
     `/etc/chrony/sources.d/pool-ntp-org.sources` written with `pool`/`server` lines and
     `chronyc reload sources` succeeds.
   - `component/zabbix-agent2.sh` — prompts for server (required) and hostname (default `$(hostname)`);
     confirm the Zabbix **7.4** repo is added, `zabbix-agent2` installed,
     `/etc/zabbix/zabbix_agent2.d/zabbix_agent2.conf` written, service enabled. (Unattended runs must
     pass `ZABBIX_AGENT2__SERVER=…` since there is no default.)
   - `component/zabbix-proxy.sh` — proxy-only; prompts for server (required) and hostname (default
     `$(hostname)`); confirm `zabbix-proxy-sqlite3` installed and the proxy conf written.
4. **Composite `zabbix/install-sm-proxy.sh install`** — the important one:
   - whiptail asks **customer** + **location** only (no server prompt — it's pinned);
   - **one** `apt install` line lists `zabbix-agent2 zabbix-proxy-sqlite3 chrony` together;
   - the Zabbix **7.0** repo is added **once** (not twice);
   - both confs get `Hostname=<customer>-proxy-<location>`; proxy conf has the TLS PSK block;
   - Swiss NTP configured; PSK printed at the end; `zabbix-agent2` + `zabbix-proxy` restarted together.
5. **`3cx/post-install.sh install`** — composite including agent2 + chrony at repo **7.4**; verify the
   single batched install of `zabbix-agent2 chrony` and the Swiss NTP pool from the chrony component.
6. **`proxmox/post-install.sh install`** — chrony + unattended-upgrades installed; `unattended-upgrades`
   enabled.

Verify `update` and `remove` modes on at least chrony and the composite (remove → grouped
`systemctl disable --now` + `apt purge`).

## Known follow-ups / decisions pending

- ~~`framework/script.func` / `add_application`.~~ **Resolved:** the framework was flattened,
  re-layered and renamed. `script.func` → `composite.func` (composite entry point that also provides
  `include_component`); `installer.func` → `component.func` with the engine extracted to a dedicated
  `engine.func`; `tools.func` → `component-tools.func`; `installer/` → `component/`. `add_application`
  and the dead `APP` var were removed; `generate_psk` (single-use) was inlined into install-sm-proxy.sh;
  `add_service` → `add_services`. The `<slug>_register()` wrapper + `_COMPOSING` guard are gone
  (components are flat; the engine owns the compose decision in `installer_run`). Swiss NTP now goes
  through the chrony component (`include_component chrony`, `CHRONY__SOURCE=swiss`), so the old
  `configure_swiss_ntp` composite helper was dropped.
- `zabbix/install-sm-proxy.sh` no longer has its old hand-built wizard; customer/location now go
  through the declarative prompt registry. Confirm the UX is acceptable on a real terminal.
- `setup_zabbix_repo` URL format was verified against the live repo for 7.0 and 8.0 (≤7.0 →
  `/zabbix/<v>/<id>/`, ≥7.2 → `/zabbix/<v>/release/<id>/`, filename `zabbix-release_latest_<v>+<id><ver>_all.deb`).
  Re-check 7.4 specifically when testing 3cx.
- The interactive whiptail path could not be exercised on Windows; watch for `/dev/tty` / pipe
  behaviour when run as `wget … | bash` (handled via `is_unattended` checking `/dev/tty`).
