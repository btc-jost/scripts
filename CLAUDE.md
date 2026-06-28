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
  A **composite**: `include_component zabbix-agent2` + `zabbix-proxy`, then a customer/location wizard
  (→ hostname `<customer>-proxy-<location>`), PSK and Swiss NTP. The whole thing runs as one combined
  lifecycle (single `apt install`, grouped service restart).
- `proxmox/post-install.sh` — framework component: chrony (Swiss NTP) + unattended-upgrades.

`framework/` — sourced Bash libraries (`.func`, `# shellcheck shell=bash`): an event-driven installer
mini-framework, layered as single-purpose modules. Two kinds of leaf script, two entry points:
- A **component** (in `component/`) sources `component.func` and is a **flat** script with a fixed
  section order: **contract vars** (with `:-` defaults so a composite can override, e.g.
  `ZABBIX_VERSION`) → **func calls** (`add_packages`/`add_services` + `register_question`/
  `register_event_handler`, which run at source time) → plain **funcs** → **event funcs** (the
  handler definitions) → `installer_run "$@"`. Components never assign `APP_PACKAGES`/`APP_SERVICES`;
  they only add. All real work sits in event handlers. There is **no** `<slug>_register()` wrapper and
  **no** `_COMPOSING` guard — the framework owns the compose decision (`installer_run` no-ops when
  `_COMPOSING` is set). Each component `register_question`s the config values it needs; a value preset
  before the wizard is not asked. Composites follow the same section order.
- **Composition:** a **composite** (top-level script) sources `composite.func`, sets a component's
  contract vars **first**, then calls `include_component <slug>` (sources a sibling under
  `_COMPOSING`, so the sibling's registrations run while its trailing `installer_run` no-ops), adds
  its own questions/handlers, and calls ONE `installer_run`. The core then does the heavy work once
  for the whole run: a single batched `apt install` of `APP_PACKAGES`, one grouped
  `systemctl enable/restart` of `APP_SERVICES`. **Ordering matters:** contract vars must precede the
  matching `include_component`, since the component reads them at source time.

Libs are sourced from `${FUNC_BASE_URL:-…/main}/framework/*.func` and carry load-once guards
(`_CORE_FUNC_LOADED` etc.) so they can be pre-sourced locally for testing.
- `framework/core.func` — pure utilities: colors/formatting/icons, `msg_info|ok|error|warn`,
  `silent()` + `set_std_mode` (`STD="silent"`), `load_functions`, `shell_check`, `root_check`,
  `is_unattended`, `exit_script`. Sourced by everything.
- `framework/engine.func` — the installer engine: event registry (`register_event_handler`,
  `run_event`), `add_packages`/`add_services` accumulators, batched default handlers (install/upgrade/
  purge of `APP_PACKAGES`, grouped enable/disable of `APP_SERVICES`), and `installer_run`
  orchestrating install/update/remove. Order per mode: `configure` event → `run_questions` (so a
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
- `framework/component-tools.func` — helpers shared by ≥2 components: `setup_zabbix_repo`
  (version-aware repo URL, idempotent) and its `_version_ge`. Single-use helpers stay inline in
  their script (e.g. `generate_psk` lives in `install-sm-proxy.sh`); there is no composite-tools lib.
- `framework/component.func` — **component entry point**: sources core + engine + prompt +
  component-tools.
- `framework/composite.func` — **composite entry point**: sources core + engine + prompt, and
  provides `include_component` (resolves `component/<slug>.sh`, locally via `COMPONENT_LOCAL_DIR`).

`component/` — reusable component units (flat; runnable directly via `component.func`, or
`include_component`-ed by a composite):
- `component/chrony.sh` — a `menu` + `input_list` NTP-source question and a single config-write
  handler. The reference worked example.
- `component/zabbix-agent2.sh` — agent2 package/service, repo setup in `pre_install`, conf write in
  `post_install`. Asks `ZABBIX_AGENT2__SERVER` and `ZABBIX_AGENT2__HOSTNAME` (default `$(hostname)`);
  both auto-omitted when a composite presets them.
- `component/zabbix-proxy.sh` — **proxy package only**, asks `ZABBIX_PROXY__SERVER` and
  `ZABBIX_PROXY__HOSTNAME` (default `$(hostname)`); writes the proxy conf, taking `_ZABBIX_PROXY__DB_PATH`
  and optional `_ZABBIX_PROXY__PSK_FILE` from internal contract vars.

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
- Naming: `<area>/<verb>-<thing>.sh`; event handlers follow `<module>_<event>` (e.g. `chrony_post_install`).
- Variables are `<MODULE>__<NAME>` — the module name in caps (`CHRONY`, `ZABBIX_AGENT2`,
  `ZABBIX_PROXY`, `SM_PROXY`) joined to the name by a **double underscore**. A **leading `_`** marks an
  internal/script-only var (`_ZABBIX_PROXY__CONF`); without the leading `_` it is a wizard input used
  in a `register_question` call (`ZABBIX_AGENT2__SERVER`). Exception: `ZABBIX_VERSION` is a single
  shared var read by `setup_zabbix_repo`.
- Every script begins with the standard GPL-3.0 header block.
