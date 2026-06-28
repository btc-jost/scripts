#!/usr/bin/env bash
#
# btc Helper Scripts - Proxmox Post-Installation Script
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
[[ -n "${_COMPOSITE_FUNC_LOADED:-}" ]] || source <(wget -qO- "${FUNC_BASE_URL}/framework/composite.func")

# --- Declaration -------------------------------------------------------------
_ZABBIX_AGENT2__CONF="${_ZABBIX_AGENT2__CONF:-/etc/zabbix/zabbix_agent2.d/smartmonitoring.conf}"
ZABBIX_VERSION="${ZABBIX_VERSION:-7.0}"
ZABBIX_AGENT2__HOSTNAME="${ZABBIX_AGENT2__HOSTNAME:-$(hostname)}"
# Swiss NTP comes from the chrony component; preset its source to skip the prompt.
CHRONY__SOURCE="${CHRONY__SOURCE:-swiss}"

include_component zabbix-agent2
include_component chrony
# unattended-upgrades is installed in the batched apt run and enabled/restarted by
# the engine's grouped service step - no dedicated handler needed.
add_packages unattended-upgrades
add_services unattended-upgrades

installer_run "$@"
