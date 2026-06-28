#!/usr/bin/env bash
#
# btc Helper Scripts - 3CX Post-Installation Script (composite)
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

include_installer zabbix-agent2

# --- Declaration -------------------------------------------------------------
APP="3CX Post-Install"
ZABBIX_VERSION="${ZABBIX_VERSION:-7.4}"
ZBX_SERVER="${ZBX_SERVER:-192.168.72.5}"
_AGENT_CONF="${_AGENT_CONF:-/etc/zabbix/zabbix_agent2.d/smart_monitoring.conf}"

zabbix_agent2_register
add_packages chrony
add_service chronyd

threecx_post_install() {
  configure_swiss_ntp
}
register_event_handler post_install threecx_post_install

installer_run "$@"
