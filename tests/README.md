# Testing & WSL2 continuation guide

This note captures everything needed to continue developing/testing the installer framework on a
real Linux box (WSL2 Ubuntu / a throwaway LXC). The framework is feature-complete and verified
with a stubbed dry-run harness on Windows; the remaining work is **real** `apt`/`whiptail`/`systemd`
execution, which can only happen on Linux.

## What exists

Event-driven Bash installer framework under `framework/`, reusable component units under
`installer/`, and composites (`zabbix/install-sm-proxy.sh`, `3cx/post-install.sh`). See the repo
`CLAUDE.md` for the full architecture. Key ideas:

- A **component** = `<slug>_register()` (enhances the shared `APP_PACKAGES`/`APP_SERVICES`
  collections via `add_packages`/`add_service`, registers questions + event handlers) plus a
  guarded standalone entry. All real work lives in event handlers.
- **Composition:** a top-level script calls `include_installer <slug>` (sources a sibling in compose
  mode), then the `<slug>_register` functions, adds its own steps, and runs ONE `installer_run`. The
  core then does one batched `apt install` and one grouped `systemctl enable/restart`.
- **Prompts** are declarative (`register_question`), rendered by a multi-step whiptail wizard, with
  unattended fallback to declared defaults.

## Local dry-run harness (no root, no Debian)

```bash
bash tests/harness.sh <script> [mode]
CUSTOMER=acme LOCATION=zrh bash tests/harness.sh zabbix/install-sm-proxy.sh install
```

Stubs `apt-get`/`systemctl`/`dpkg`/`wget`/`chronyc`/`openssl` and the `setup_zabbix_repo` /
`configure_swiss_ntp` helpers, redirects config writes under a temp dir, and asserts the batched
install + grouped restart + repo idempotency. Good for checking event ordering and composition; it
does **not** prove the real package install works.

Quick syntax sweep:
```bash
for f in framework/*.func installer/*.sh zabbix/*.sh 3cx/*.sh proxmox/*.sh tests/*.sh; do bash -n "$f"; done
```

## WSL2 / LXC real-test checklist

Prereqs: Debian/Ubuntu, root, `whiptail` installed (`apt-get install -y whiptail`), `shellcheck`
for linting (`apt-get install -y shellcheck`).

1. **Lint:** `shellcheck framework/*.func installer/*.sh zabbix/*.sh 3cx/*.sh proxmox/*.sh`
   (libs carry `# shellcheck shell=bash`). Fix anything that surfaces — this could not run on
   Windows (no shellcheck there).
2. **Branch sourcing:** these scripts source siblings from `${FUNC_BASE_URL}/framework|installer/...`.
   This branch is `dev-framework`. To test the pushed branch end-to-end via the canonical pipe:
   ```bash
   export FUNC_BASE_URL=https://raw.githubusercontent.com/btc-jost/scripts/dev-framework
   wget -O - "$FUNC_BASE_URL/installer/chrony.sh" | bash -s install
   ```
   To test the working tree directly without pushing, run files in place:
   `sudo bash installer/chrony.sh install` (it still pulls libs from `FUNC_BASE_URL` unless you set
   `INSTALLER_LOCAL_DIR` and pre-source the local `framework/*.func`).
3. **Standalone components** (`bash <script> install`, also `update` / `remove`):
   - `installer/chrony.sh` — wizard picks Swiss pool vs custom; confirm
     `/etc/chrony/sources.d/pool-ntp-org.sources` written with `pool`/`server` lines and
     `chronyc reload sources` succeeds.
   - `installer/zabbix-agent2.sh` — prompts for server (default `192.168.72.5`); confirm the Zabbix
     **8.0** repo is added, `zabbix-agent2` installed, `/etc/zabbix/zabbix_agent2.d/smart_monitoring.conf`
     written, service enabled.
   - `installer/zabbix-proxy.sh` — proxy-only; confirm `zabbix-proxy-sqlite3` installed and the proxy
     conf written from the contract vars.
4. **Composite `zabbix/install-sm-proxy.sh install`** — the important one:
   - whiptail asks **customer** + **location** only (no server prompt — it's pinned);
   - **one** `apt install` line lists `zabbix-agent2 zabbix-proxy-sqlite3` together;
   - the Zabbix **7.0** repo is added **once** (not twice);
   - both confs get `Hostname=<customer>-proxy-<location>`; proxy conf has the TLS PSK block;
   - Swiss NTP configured; PSK printed at the end; `zabbix-agent2` + `zabbix-proxy` restarted together.
5. **`3cx/post-install.sh install`** — composite including agent2 (repo **7.4**) + chrony; verify the
   single batched install and that agent2's version default (8.0) was overridden to 7.4.
6. **`proxmox/post-install.sh install`** — chrony + unattended-upgrades installed; `unattended-upgrades`
   enabled.

Verify `update` and `remove` modes on at least chrony and the composite (remove → grouped
`systemctl disable --now` + `apt purge`).

## Known follow-ups / decisions pending

- `framework/script.func` still defines an `add_application` helper that no component uses now —
  decide whether to keep it as sugar or drop it.
- `zabbix/install-sm-proxy.sh` no longer has its old hand-built wizard; customer/location now go
  through the declarative prompt registry. Confirm the UX is acceptable on a real terminal.
- `setup_zabbix_repo` URL format was verified against the live repo for 7.0 and 8.0 (≤7.0 →
  `/zabbix/<v>/<id>/`, ≥7.2 → `/zabbix/<v>/release/<id>/`, filename `zabbix-release_latest_<v>+<id><ver>_all.deb`).
  Re-check 7.4 specifically when testing 3cx.
- The interactive whiptail path could not be exercised on Windows; watch for `/dev/tty` / pipe
  behaviour when run as `wget … | bash` (handled via `is_unattended` checking `/dev/tty`).
