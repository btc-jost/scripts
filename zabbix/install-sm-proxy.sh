#!/usr/bin/env bash
#
# btc Helper Scripts - SmartMonitoring Proxy Installation Script (composite)
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
#
# A SmartMonitoring proxy is just the Zabbix proxy + agent2 components composed
# together, plus the customer/location naming, a PSK and Swiss NTP. This script
# includes those two installers and layers the SmartMonitoring specifics on top;
# the core runs everything as one combined lifecycle (one apt install, etc.).

FUNC_BASE_URL="${FUNC_BASE_URL:-https://raw.githubusercontent.com/btc-jost/scripts/main}"
# shellcheck disable=SC1090
[[ -n "${_COMPOSITE_FUNC_LOADED:-}" ]] || source <(wget -qO- "${FUNC_BASE_URL}/framework/composite.func")

# --- SmartMonitoring contract -----------------------------------------------
# Set BEFORE the includes: the components read these at source time. Pinning the
# servers / CHRONY__SOURCE here also suppresses the components' matching questions
# (only customer + location are left to ask).
ZABBIX_VERSION="${ZABBIX_VERSION:-7.0}"
ZABBIX_AGENT2__SERVER="${ZABBIX_AGENT2__SERVER:-localhost}"
ZABBIX_PROXY__SERVER="${ZABBIX_PROXY__SERVER:-monitoring.smartcollab.ch}"
# Hostnames are derived from customer+location in smproxy_pre_install; preset them
# (non-empty) so the agent/proxy components don't prompt for them.
ZABBIX_AGENT2__HOSTNAME="${ZABBIX_AGENT2__HOSTNAME:-$(hostname)}"
ZABBIX_PROXY__HOSTNAME="${ZABBIX_PROXY__HOSTNAME:-$(hostname)}"
_ZABBIX_PROXY__PSK_FILE="${_ZABBIX_PROXY__PSK_FILE:-/etc/zabbix/psk.key}"
_ZABBIX_PROXY__DB_PATH="${_ZABBIX_PROXY__DB_PATH:-/var/lib/sqlite/zabbix-proxy.db}"
_ZABBIX_AGENT2__CONF="${_ZABBIX_AGENT2__CONF:-/etc/zabbix/zabbix_agent2.d/smartmonitoring.conf}"
_ZABBIX_PROXY__CONF="${_ZABBIX_PROXY__CONF:-/etc/zabbix/zabbix_proxy.d/smartmonitoring.conf}"
CHRONY__SOURCE="${CHRONY__SOURCE:-swiss}"

include_component zabbix-agent2
include_component zabbix-proxy
include_component chrony
register_question SM_PROXY__CUSTOMER input "Set customer name" validate=alnum title=Customer
register_question SM_PROXY__LOCATION input "Set location" validate=alnum title=Location
register_event_handler pre_install smproxy_pre_install
register_event_handler post_install smproxy_post_install

# generate_psk [keyfile] - create a 256-byte hex PSK if one does not exist.
# Inlined here (single-use): only this composite generates a PSK. Idempotent.
generate_psk() {
  local keyfile="${1:-/etc/zabbix/psk.key}"
  if [[ -f "$keyfile" ]]; then
    msg_warn "PSK key already exists at ${keyfile}; keeping it"
    return 0
  fi
  msg_info "Generating PSK key"
  mkdir -p "$(dirname "$keyfile")"
  openssl rand -hex 256 >"$keyfile"
  msg_ok "Generated PSK key"
}

# Derive the proxy hostname and key BEFORE the components write their configs.
smproxy_pre_install() {
  local hn="${SM_PROXY__CUSTOMER,,}-proxy-${SM_PROXY__LOCATION,,}"
  # shellcheck disable=SC2034  # read by component/zabbix-agent2.sh when it writes the agent conf
  ZABBIX_AGENT2__HOSTNAME="$hn"
  ZABBIX_PROXY__HOSTNAME="$hn"
  generate_psk "$_ZABBIX_PROXY__PSK_FILE"
}

smproxy_post_install() {
  echo
  msg_ok "SmartMonitoring Proxy installation completed"
  echo "Proxy hostname: ${ZABBIX_PROXY__HOSTNAME}"
  echo "PSK key:"
  cat "$_ZABBIX_PROXY__PSK_FILE"
  echo
  echo "Add the PSK key to the Zabbix server so the proxy can connect."
}

installer_run "$@"
