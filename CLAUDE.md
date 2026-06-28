# scripts

A collection of **Bash provisioning / post-install scripts** for btc.jost AG infrastructure —
Debian/Ubuntu hosts and Proxmox/LXC containers. They bootstrap monitoring (Zabbix), time sync
(chrony) and 3CX servers. Designed to be piped straight into a root shell from GitHub raw URLs.

License: GPL-3.0 (see `LICENSE`); every script carries the GPL header. Author: Simon Gilli / btc.jost AG.

## Inventory

Standalone scripts (each runnable on its own):
- `3cx/post-install.sh` — after a fresh 3CX install on Debian: a framework component that adds the
  Zabbix repo, installs + configures `zabbix-agent2` (Server `192.168.72.5`) and chrony with the
  Swiss NTP pool.
- `zabbix/install-sm-proxy.sh` — install a **SmartMonitoring proxy** (Zabbix 7.0) on Debian/Ubuntu.
  A **composite**: `include_installer zabbix-agent2` + `zabbix-proxy`, then a customer/location wizard
  (→ hostname `<customer>-proxy-<location>`), PSK and Swiss NTP. The whole thing runs as one combined
  lifecycle (single `apt install`, grouped service restart).
- `proxmox/post-install.sh` — framework component: chrony (Swiss NTP) + unattended-upgrades.

`framework/` — sourced Bash libraries (`.func`, `# shellcheck shell=bash`): an event-driven installer
mini-framework. Two reuse mechanisms:
- A **component is purely declarative** — it sets a few package-specific vars (with `:-` defaults so a
  composite can override, e.g. `ZABBIX_VERSION`), and a **registration unit** `<slug>_register()`
  *enhances* the shared collections via `add_packages`/`add_service` and registers handlers/questions.
  Components never assign `APP_PACKAGES`/`APP_SERVICES` — they only add. All real work sits in event
  handlers; the only top-level statement is a guarded standalone entry that calls `<slug>_register`
  + `installer_run "$@"` when run directly (skipped under `_COMPOSING`).
- **Composition:** a top-level script calls `include_installer <slug>` (sources a sibling in compose
  mode so its standalone entry does not fire), then calls the `<slug>_register` functions it wants,
  adds its own questions/handlers, and runs ONE `installer_run`. The core then does the heavy work
  once for the whole run: a single batched `apt install` of `APP_PACKAGES`, one grouped
  `systemctl enable/restart` of `APP_SERVICES`.

Libs are sourced from `${FUNC_BASE_URL:-…/main}/framework/*.func` and carry load-once guards
(`_CORE_FUNC_LOADED` etc.) so they can be pre-sourced locally for testing.
- `framework/core.func` — colors/formatting/icons, `msg_info|ok|error|warn`, `silent()` + `set_std_mode`
  (`STD="silent"`), `load_functions`, `shell_check`, `root_check`, `is_unattended`, `exit_script`.
- `framework/installer.func` — event registry (`register_event_handler`, `run_event`),
  `add_packages`/`add_service` accumulators, `include_installer`, batched default handlers
  (install/upgrade/purge of `APP_PACKAGES`, grouped enable/disable of `APP_SERVICES`), and
  `installer_run` orchestrating install/update/remove around `configure`/`pre_*`/`*`/`post_*` events.
- `framework/prompt.func` — declarative question registry: `register_question <KEY> <type> <prompt>
  [opts]` (`input`/`menu`/`yesno`/`input_list`, with `default=`/`validate=`/`when=`); `run_questions`
  renders a multi-step whiptail wizard (Next/Back/Exit) and stores answers in `$KEY`, falling back to
  declared defaults when unattended.
- `framework/tools.func` — shared helpers: `setup_zabbix_repo` (version-aware repo URL, idempotent),
  `generate_psk`, `configure_swiss_ntp`.
- `framework/script.func` — convenience entry that sources installer.func + tools.func; `add_application`.

`installer/` — reusable component units (each defines `<slug>_register()` + a guarded standalone
entry; runnable directly or `include_installer`-ed by a composite):
- `installer/chrony.sh` — `chrony_register`: a `menu` + `input_list` NTP-source question and a single
  config-write handler. The reference worked example.
- `installer/zabbix-agent2.sh` — `zabbix_agent2_register`: agent2 package/service, repo setup in
  `pre_install`, conf write in `post_install`. Reads `ZBX_SERVER`/`ZBX_AGENT_HOSTNAME`; suppresses the
  server question when `ZBX_SERVER` is preset.
- `installer/zabbix-proxy.sh` — `zabbix_proxy_register`: **proxy package only**, writes the proxy conf
  from contract vars (`ZBX_SERVER`, `ZBX_PROXY_HOSTNAME`, `ZBX_DB_PATH`, optional `ZBX_PSK_FILE`).

## How to run

Standalone scripts are meant to be piped into a root shell from GitHub raw, e.g.:
```bash
wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/3cx/post-install.sh | bash
wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/zabbix/install-sm-proxy.sh | bash
```
- **Bash only** (not POSIX sh) — `core.func`'s `shell_check` enforces it. Run **as root** (`root_check`).
- Targets **Debian/Ubuntu** (`apt`, reads `/etc/os-release`). Interactive scripts need `whiptail`;
  set `UNATTENDED=yes` to skip prompts and use declared defaults.
- Framework components take a mode argument: `… | bash -s install` (default), `update`, or `remove`.
- Libs are sourced from `${FUNC_BASE_URL:-…/main}/framework/*.func`. To test an unmerged branch,
  export `FUNC_BASE_URL=…/<branch>`; locally, pre-source the `framework/*.func` files (load guards
  make the remote `source` lines no-ops) — see the harness pattern used during development.

## Conventions

- Language: Bash. Indent 2 spaces, LF endings, UTF-8, final newline (`.editorconfig`).
  `*.sh` and `*.func` are forced to `eol=lf` (`.gitattributes`); `.vscode/*.json` uses CRLF + 4-space.
- Lint with **shellcheck** (libs start with `# shellcheck shell=bash`; inline `# shellcheck disable=...`
  where needed). Recommended VS Code extensions in `.vscode/extensions.json`: shellcheck, shell-format,
  shell-syntax, markdownlint, editorconfig.
- Naming: `<area>/<verb>-<thing>.sh`; framework hooks follow `<event>_<component>` (e.g. `install_chrony`).
- Every script begins with the standard GPL-3.0 header block.
