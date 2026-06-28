#!/usr/bin/env bash
#
# btc Helper Scripts - Zabbix Proxy Installation Script
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

_PROXY_CONF="${_PROXY_CONF:-/etc/zabbix/zabbix_proxy.d/zabbix-proxy.conf}"

# Reusable unit: opt this component in by calling zabbix_proxy_register.
# Contract vars: ZBX_SERVER (required), ZBX_PROXY_HOSTNAME (default $(hostname)),
#   ZBX_DB_PATH, ZBX_PSK_FILE/ZBX_PSK_IDENTITY (TLS PSK lines only if file set).
zabbix_proxy_register() {
  add_packages zabbix-proxy-sqlite3
  add_service zabbix-proxy
  register_event_handler pre_install zabbix_proxy_pre_install
  register_event_handler post_install zabbix_proxy_post_install
}

zabbix_proxy_pre_install() {
  setup_zabbix_repo
}

zabbix_proxy_post_install() {
  local hostname="${ZBX_PROXY_HOSTNAME:-$(hostname)}"
  local db="${ZBX_DB_PATH:-/var/lib/sqlite/zabbix-proxy.db}"

  msg_info "Configuring Zabbix proxy"
  mkdir -p "$(dirname "$_PROXY_CONF")"
  {
    printf 'Server=%s\n' "${ZBX_SERVER:?ZBX_SERVER must be set}"
    printf 'Hostname=%s\n' "$hostname"
    printf 'DBName=%s\n' "$db"
    if [[ -n "${ZBX_PSK_FILE:-}" ]]; then
      printf 'TLSConnect=psk\nTLSAccept=psk\nTLSPSKIdentity=%s\nTLSPSKFile=%s\n' \
        "${ZBX_PSK_IDENTITY:-$hostname}" "$ZBX_PSK_FILE"
    fi
  } >"$_PROXY_CONF"

  mkdir -p "$(dirname "$db")"
  $STD chown zabbix:zabbix "$(dirname "$db")" || true
  msg_ok "Configured Zabbix proxy"
}

# Standalone entrypoint (skipped when included via include_installer).
if [[ -z "${_COMPOSING:-}" ]]; then
  APP="${APP:-Zabbix Proxy}"
  ZABBIX_VERSION="${ZABBIX_VERSION:-7.0}"
  ZBX_SERVER="${ZBX_SERVER:-monitoring.smartcollab.ch}"
  zabbix_proxy_register
  installer_run "$@"
fi
