#!/usr/bin/env bash
#
# btc Helper Scripts - Zabbix Proxy Installation Script
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

# Contract vars (set before include_component to suppress the matching question or
# supply advanced values): ZABBIX_PROXY__SERVER, ZABBIX_PROXY__HOSTNAME,
#   _ZABBIX_PROXY__DB_PATH, _ZABBIX_PROXY__PSK_FILE/_ZABBIX_PROXY__PSK_IDENTITY (TLS PSK lines only if file set).
_ZABBIX_PROXY__CONF="${_ZABBIX_PROXY__CONF:-/etc/zabbix/zabbix_proxy.d/zabbix-proxy.conf}"
ZABBIX_VERSION="${ZABBIX_VERSION:-7.4}"

set_app_id zabbix-proxy
include_component zabbix-release # adds the Zabbix apt repo (owns/removes zabbix-release)
# Service declared: the framework restarts it to apply the proxy conf we write.
add_package zabbix-proxy-sqlite3 zabbix-proxy
# A composite that pins these beforehand suppresses the matching question automatically.
register_question ZABBIX_PROXY__SERVER input "Zabbix server address" validate=nonempty \
  title="Zabbix server"
register_question ZABBIX_PROXY__HOSTNAME input "Zabbix proxy hostname" \
  default="$(hostname)" validate=nonempty title="Proxy hostname"
register_event_handler post_install zabbix_proxy_post_install
register_event_handler pre_remove zabbix_proxy_pre_remove

# Remove the proxy conf and sqlite DB we created - only if this run purges the proxy.
zabbix_proxy_pre_remove() {
  will_remove zabbix-proxy-sqlite3 || return 0
  msg_info "Removing Zabbix proxy configuration"
  rm -f "$_ZABBIX_PROXY__CONF" "${_ZABBIX_PROXY__DB_PATH:-/var/lib/sqlite/zabbix-proxy.db}"
  msg_ok "Removed Zabbix proxy configuration"
}

zabbix_proxy_post_install() {
  local hostname="$ZABBIX_PROXY__HOSTNAME"
  local db="${_ZABBIX_PROXY__DB_PATH:-/var/lib/sqlite/zabbix-proxy.db}"

  msg_info "Configuring Zabbix proxy"
  mkdir -p "$(dirname "$_ZABBIX_PROXY__CONF")"
  {
    printf 'Server=%s\n' "${ZABBIX_PROXY__SERVER:?ZABBIX_PROXY__SERVER must be set}"
    printf 'Hostname=%s\n' "$hostname"
    printf 'DBName=%s\n' "$db"
    if [[ -n "${_ZABBIX_PROXY__PSK_FILE:-}" ]]; then
      printf 'TLSConnect=psk\nTLSAccept=psk\nTLSPSKIdentity=%s\nTLSPSKFile=%s\n' \
        "${_ZABBIX_PROXY__PSK_IDENTITY:-$hostname}" "$_ZABBIX_PROXY__PSK_FILE"
    fi
  } >"$_ZABBIX_PROXY__CONF"

  mkdir -p "$(dirname "$db")"
  $STD chown zabbix:zabbix "$(dirname "$db")" || true
  msg_ok "Configured Zabbix proxy"
}

installer_run "$@"
