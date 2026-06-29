#!/usr/bin/env bash
#
# btc Helper Scripts - Zabbix Agent 2 Installation Script
#
# Copyright (C) 2025-2026  btc.jost AG
# Copyright (C) 2025-2026  Simon Gilli
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
[[ -n "${_COMPONENT_FUNC_LOADED:-}" ]] || source <(wget -qO- "${FUNC_BASE_URL}/framework/component.func")

# Contract vars (set before include_component to suppress the matching question):
# ZABBIX_AGENT2__SERVER, ZABBIX_AGENT2__HOSTNAME.
_ZABBIX_AGENT2__CONF="${_ZABBIX_AGENT2__CONF:-/etc/zabbix/zabbix_agent2.d/zabbix_agent2.conf}"
ZABBIX_VERSION="${ZABBIX_VERSION:-7.4}"

set_app_id zabbix-agent2
# Service declared: the framework restarts it to apply the Server=/Hostname= conf we write.
add_package zabbix-agent2 zabbix-agent2
# A composite that pins these beforehand suppresses the matching question automatically.
register_question ZABBIX_AGENT2__SERVER input "Zabbix proxy / server address" validate=nonempty \
  title="Zabbix server"
register_question ZABBIX_AGENT2__HOSTNAME input "Zabbix agent hostname" \
  default="$(hostname)" validate=nonempty title="Agent hostname"
register_event_handler pre_install zabbix_agent2_pre_install
register_event_handler post_install zabbix_agent2_post_install

zabbix_agent2_pre_install() {
  setup_zabbix_repo
}

zabbix_agent2_post_install() {
  local server="${ZABBIX_AGENT2__SERVER:?ZABBIX_AGENT2__SERVER must be set}"
  msg_info "Writing agent2 configuration"
  mkdir -p "$(dirname "$_ZABBIX_AGENT2__CONF")"
  printf 'Server=%s\nServerActive=%s\nHostname=%s\n' \
    "$server" "$server" "$ZABBIX_AGENT2__HOSTNAME" >"$_ZABBIX_AGENT2__CONF"
  msg_ok "Wrote agent2 configuration"
}

installer_run "$@"
