#!/usr/bin/env bash
#
# btc Helper Scripts - SmartMonitoring Proxy Installation Script (composite)
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
#
# A SmartMonitoring proxy is just the Zabbix proxy + agent2 components composed
# together, plus the customer/location naming, a PSK and Swiss NTP. This script
# includes those two installers and layers the SmartMonitoring specifics on top;
# the core runs everything as one combined lifecycle (one apt install, etc.).

FUNC_BASE_URL="${FUNC_BASE_URL:-https://raw.githubusercontent.com/btc-jost/scripts/main}"
# shellcheck disable=SC1090
[[ -n "${_INSTALLER_FUNC_LOADED:-}" ]] || source <(wget -qO- "${FUNC_BASE_URL}/framework/installer.func")

include_installer zabbix-agent2
include_installer zabbix-proxy

# --- SmartMonitoring declaration --------------------------------------------
APP="SmartMonitoring Proxy"
ZABBIX_VERSION="${ZABBIX_VERSION:-7.0}"
# Fixed central server; setting it before the includes also suppresses agent2's
# "Zabbix server address" question.
ZBX_SERVER="${ZBX_SERVER:-monitoring.smartcollab.ch}"
ZBX_PSK_FILE="${ZBX_PSK_FILE:-/etc/zabbix/psk.key}"
ZBX_DB_PATH="${ZBX_DB_PATH:-/var/lib/sqlite/zabbix-proxy.db}"
_AGENT_CONF="${_AGENT_CONF:-/etc/zabbix/zabbix_agent2.d/smartmonitoring.conf}"
_PROXY_CONF="${_PROXY_CONF:-/etc/zabbix/zabbix_proxy.d/smartmonitoring.conf}"

register_question CUSTOMER input "Set customer name" validate=alnum
register_question LOCATION input "Set location" validate=alnum

zabbix_agent2_register
zabbix_proxy_register

# Derive the proxy hostname and key BEFORE the components write their configs.
smproxy_prep() {
  local hn="${CUSTOMER,,}-proxy-${LOCATION,,}"
  ZBX_AGENT_HOSTNAME="$hn"
  ZBX_PROXY_HOSTNAME="$hn"
  generate_psk "$ZBX_PSK_FILE"
}
register_event_handler pre_install smproxy_prep

smproxy_finalize() {
  configure_swiss_ntp
  echo
  msg_ok "SmartMonitoring Proxy installation completed"
  echo "Proxy hostname: ${ZBX_PROXY_HOSTNAME}"
  echo "PSK key:"
  cat "$ZBX_PSK_FILE"
  echo
  echo "Add the PSK key to the Zabbix server so the proxy can connect."
}
register_event_handler post_install smproxy_finalize

installer_run "$@"
