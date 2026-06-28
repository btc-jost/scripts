#!/usr/bin/env bash
#
# btc Helper Scripts - Zabbix Agent 2 Installation Script
#
# Copyright (C) 2025  btc.jost AG
# Copyright (C) 2025  Simon Gilli
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

FUNC_BASE_URL="${FUNC_BASE_URL:-https://raw.githubusercontent.com/btc-jost/scripts/main}"
# shellcheck disable=SC1090
[[ -n "${_INSTALLER_FUNC_LOADED:-}" ]] || source <(wget -qO- "${FUNC_BASE_URL}/framework/installer.func")

_AGENT_CONF="${_AGENT_CONF:-/etc/zabbix/zabbix_agent2.d/smart_monitoring.conf}"

# Reusable unit: opt this component in by calling zabbix_agent2_register.
# Contract vars (set before calling, optional): ZBX_SERVER, ZBX_AGENT_HOSTNAME.
zabbix_agent2_register() {
  add_packages zabbix-agent2
  add_service zabbix-agent2
  # Only ask for the server when a composite has not already pinned it.
  [[ -z "${ZBX_SERVER:-}" ]] &&
    register_question ZBX_SERVER input "Zabbix server address" \
      default=192.168.72.5 validate=nonempty
  register_event_handler pre_install zabbix_agent2_pre_install
  register_event_handler post_install zabbix_agent2_post_install
}

zabbix_agent2_pre_install() {
  setup_zabbix_repo
}

zabbix_agent2_post_install() {
  msg_info "Writing agent2 configuration"
  mkdir -p "$(dirname "$_AGENT_CONF")"
  printf 'Server=%s\nServerActive=%s\nHostname=%s\n' \
    "$ZBX_SERVER" "$ZBX_SERVER" "${ZBX_AGENT_HOSTNAME:-}" >"$_AGENT_CONF"
  msg_ok "Wrote agent2 configuration"
}

# Standalone entrypoint (skipped when included via include_installer).
if [[ -z "${_COMPOSING:-}" ]]; then
  APP="${APP:-Zabbix Agent 2}"
  ZABBIX_VERSION="${ZABBIX_VERSION:-8.0}"
  zabbix_agent2_register
  installer_run "$@"
fi
