# scripts

A collection of **Bash provisioning / post-install scripts** for btc.jost AG infrastructure —
Debian/Ubuntu hosts and Proxmox/LXC containers. They bootstrap monitoring (Zabbix), time sync
(chrony) and 3CX servers. Run from GitHub raw in a root shell via `bash -c "$(wget …)"` (see How to run).

License: GPL-3.0 (see `LICENSE`); every script carries the GPL header. Author: Simon Gilli / btc.jost AG.

## Inventory

Top-level **composites** (each runnable on its own):
- `3cx/post-install.sh` — after a fresh 3CX install on Debian: composes `zabbix-agent2`
  (Server `192.168.72.5`, which pulls in `zabbix-release` for the Zabbix repo) + chrony (Swiss NTP).
- `zabbix/install-sm-proxy.sh` — install a **SmartMonitoring proxy** (Zabbix 7.0) on Debian/Ubuntu.
  Composes `zabbix-agent2` + `zabbix-proxy` (+ `zabbix-release`, `chrony`), then a customer/location
  wizard (→ hostname `<customer>-proxy-<location>`), PSK and Swiss NTP. The whole thing runs as one
  combined lifecycle (single `apt install`, grouped service restart).
- `proxmox/post-install.sh` — composes `zabbix-agent2` (+ `zabbix-release`) + chrony (Swiss NTP) and
  adds `unattended-upgrades`.

`framework/` — sourced Bash libraries (`.func`, `# shellcheck shell=bash`): an event-driven installer
mini-framework, layered as single-purpose modules. Two kinds of leaf script, two entry points:
- A **component** (in `component/`) sources `component.func` and is a **flat** script with a fixed
  section order: **contract vars** (with `:-` defaults so a composite can override, e.g.
  `ZABBIX_VERSION`) → **func calls** (`set_app_id <slug>` + `add_package <pkg> [svc...]` +
  `register_question`/`register_event_handler`, which run at source time) → plain **funcs** → **event
  funcs** (the handler definitions) → `installer_run "$@"`. Components go through framework funcs only —
  they never read/write framework globals (`APP_PACKAGES`/`APP_SERVICES`/`_APP_ID`) directly. All real
  work sits in event handlers. There is **no** `<slug>_register()` wrapper and **no** `_COMPOSING`
  guard — the framework owns the compose decision (`installer_run` no-ops when `_COMPOSING` is set).
  Each component `register_question`s the config values it needs; a value preset before the wizard is
  not asked. Composites follow the same section order.
- **Composition:** a **composite** (top-level script) sources `composite.func`, calls
  `set_app_id <slug>` and sets a component's contract vars **first**, then calls
  `include_component <slug>` (sources a sibling under `_COMPOSING`, so the sibling's registrations run
  while its trailing `installer_run` no-ops), adds its own questions/handlers, and calls ONE
  `installer_run`. Because `set_app_id` is first-caller-wins, the composite's id wins over the
  components' — packages installed in the run are owned by the composite. The core then does the heavy
  work once: a single batched `apt install`, one grouped `systemctl enable/restart` of the declared
  services, and ownership recording. **Ordering matters:** `set_app_id` and contract vars must precede
  the matching `include_component`, since the component reads them at source time.

Libs are sourced from `${FUNC_BASE_URL:-…/main}/framework/*.func` and carry load-once guards
(`_CORE_FUNC_LOADED` etc.) so they can be pre-sourced locally for testing.
- `framework/core.func` — pure utilities: colors/formatting/icons, `msg_info|ok|error|warn|note`
  (`msg_note` = a calm stdout tip), `silent()` (logs to `LOGFILE`, default
  `/var/log/btc-scripts/<ts>.log`) + `set_std_mode` (`STD="silent"`), `load_functions`,
  `shell_check`, `root_check`, `is_unattended`, `exit_script`. Sourced by everything.
- `framework/engine.func` — the installer engine: event registry (`register_event_handler`,
  `run_event`), `add_package <pkg> [svc...]` (+ legacy `add_services` for loose services),
  `set_app_id`/`get_app_id` (first-caller-wins app id), `include_component <slug>` (pull a unit into
  the run, de-duplicated — usable by composites **and** components), batched default handlers (one apt
  install/upgrade), and per-package **ownership tracking** (`_PKG_STATE_FILE`, lines `pkg=appid`): a
  package is recorded as owned only when this run actually installs it, so `remove` purges **only**
  the app's own packages and disables **only** the services those packages declare (via the
  `_PKG_SERVICES` map) — pre-existing packages and their services are left alone. Public helpers
  `pkg_installed`/`own_package` let a component track a package it installs out-of-band (e.g.
  `zabbix-release` via `dpkg -i`); `will_remove <pkg>` exposes the "this run will purge it" test so a
  component's `pre_remove` handler can clean up the config it wrote. `installer_run`
  orchestrates install/update/remove. Order per mode: `configure` event → `run_questions` (so a
  configure handler can pre-answer/suppress questions) → `pre_*`/`*`/`post_*`. Sources core.
- `framework/prompt.func` — declarative question registry: `register_question <KEY> <type> <prompt>
  [opts]` (`input`/`menu`/`yesno`/`input_list`, with `default=`/`validate=`/`when=`/`title=`);
  `run_questions` renders a multi-step whiptail wizard (Next/Back/Exit) and stores answers in `$KEY`,
  falling back to declared defaults when unattended. `title=` gives the dialog a human-readable title
  (and the summary label) instead of the raw `$KEY`. A question whose `$KEY` is already set (preset by
  a composite, env or a configure handler) is **omitted**; Back re-edits answers given during the
  wizard. When at least one real question is shown, the wizard appends two built-in steps: a
  **verbose toggle** (`VERBOSE` yes/no, omitted if `VERBOSE` is preset; the choice re-runs
  `set_std_mode`) and a **summary/confirm** page (Confirm/Back). Step numbers count only the steps
  actually shown (presets don't inflate them). Disable via `WIZARD_VERBOSE_PROMPT=no` / `WIZARD_REVIEW=no`.
- `framework/component.func` / `framework/composite.func` — the two **entry points**; both source
  core + engine + prompt. (Single-use helpers stay inline in their script, e.g. `generate_psk` in
  `install-sm-proxy.sh`; there is no shared tools lib — `setup_zabbix_repo` became the `zabbix-release`
  component.)

`component/` — reusable component units (flat; runnable directly via `component.func`, or
`include_component`-ed by a composite or another component):
- `component/chrony.sh` — a `menu` + `input_list` NTP-source question and a single config-write
  handler. The reference worked example. Custom servers can also be preset via `CHRONY__CUSTOM`.
- `component/zabbix-release.sh` — adds the Zabbix apt repo: `pre_install` `dpkg -i`s the
  version-aware `zabbix-release` deb (kept untouched if already present) and `own_package`s it;
  `add_package zabbix-release` makes the engine install/own/remove it. `include_component`-ed by the
  zabbix components (so standalone + composite runs both get the repo, deduped to once).
- `component/zabbix-agent2.sh` — agent2 package/service, `include_component zabbix-release`, conf write
  in `post_install`, conf cleanup in `pre_remove`. Asks `ZABBIX_AGENT2__SERVER` and
  `ZABBIX_AGENT2__HOSTNAME` (default `$(hostname)`); both auto-omitted when a composite presets them.
- `component/zabbix-proxy.sh` — **proxy package only**, `include_component zabbix-release`, asks
  `ZABBIX_PROXY__SERVER` and `ZABBIX_PROXY__HOSTNAME` (default `$(hostname)`); writes the proxy conf,
  taking `_ZABBIX_PROXY__DB_PATH` and optional `_ZABBIX_PROXY__PSK_FILE` from internal contract vars;
  removes conf + DB in `pre_remove`.

## How to run

Standalone scripts are meant to be run in a root shell from GitHub raw via
`bash -c "$(wget …)"` (keeps stdin on the terminal so the wizard works), e.g.:
```bash
bash -c "$(wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/3cx/post-install.sh)"
bash -c "$(wget -O - https://raw.githubusercontent.com/btc-jost/scripts/main/zabbix/install-sm-proxy.sh)"
```
- **Bash only** (not POSIX sh) — `core.func`'s `shell_check` enforces it. Run **as root** (`root_check`).
- Targets **Debian/Ubuntu** (`apt`, reads `/etc/os-release`). Interactive scripts need `whiptail`;
  set `UNATTENDED=yes` to skip prompts and use declared defaults.
- Framework components take a mode argument: install (default), `update`, or `remove`, passed after
  `--`, e.g. `bash -c "$(wget -O - …/3cx/post-install.sh)" -- update`. (The legacy `… | bash -s update`
  pipe form also works but consumes stdin.)
- Libs are sourced from `${FUNC_BASE_URL:-…/main}/framework/*.func`. To test an unmerged branch,
  export `FUNC_BASE_URL=…/<branch>`; locally, pre-source the `framework/*.func` files (load guards
  make the remote `source` lines no-ops) — see the harness pattern used during development.

## Conventions

- Language: Bash. Indent 2 spaces, LF endings, UTF-8, final newline (`.editorconfig`).
  `*.sh` and `*.func` are forced to `eol=lf` (`.gitattributes`); `.vscode/*.json` uses CRLF + 4-space.
- Lint with **shellcheck** (libs start with `# shellcheck shell=bash`; inline `# shellcheck disable=...`
  where needed). Recommended VS Code extensions in `.vscode/extensions.json`: shellcheck, shell-format,
  shell-syntax, markdownlint, editorconfig.
- Naming: `<area>/<verb>-<thing>.sh`; event handlers follow `<module>_<event>` (e.g. `chrony_post_install`).
  App ids are folder-qualified for composites (`3cx-post-install`, `zabbix-install-sm-proxy`,
  `proxmox-post-install`) since basenames repeat; component ids are their slug (`chrony`).
- Variables are `<MODULE>__<NAME>` — the module name in caps (`CHRONY`, `ZABBIX_AGENT2`,
  `ZABBIX_PROXY`, `SM_PROXY`) joined to the name by a **double underscore**. A **leading `_`** marks an
  internal/script-only var (`_ZABBIX_PROXY__CONF`); without the leading `_` it is a wizard input used
  in a `register_question` call (`ZABBIX_AGENT2__SERVER`). Exception: `ZABBIX_VERSION` is a single
  shared var read by the `zabbix-release` component.
- **Don't access framework globals directly** from components/composites — use the funcs
  (`add_package`, `add_services`, `register_question`, `register_event_handler`,
  `set_app_id`/`get_app_id`). The engine owns `APP_PACKAGES`/`APP_SERVICES`/`_APP_ID`/`_PKG_SERVICES`.
- Declare a service in `add_package <pkg> <svc>` **only** when the framework must restart it to apply
  config the script wrote (e.g. the Zabbix agent/proxy). When apt's own maintainer scripts already
  manage the service (chrony, unattended-upgrades), pass just the package.
- A component that writes config/state files should clean them up in a `pre_remove` handler gated by
  `will_remove <its pkg>`, so the files go only when that package is actually purged (not when it's
  kept because pre-existing or owned by another app).
- Every script begins with the standard GPL-3.0 header block.
