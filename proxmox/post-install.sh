#!/usr/bin/env bash
#
# btc Helper Scripts - Proxmox Post-Installation Script
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

# --- Declaration -------------------------------------------------------------
APP="Proxmox Post-Install"
add_packages chrony unattended-upgrades
add_service chronyd

proxmox_post_install() {
  configure_swiss_ntp

  msg_info "Enabling unattended-upgrades"
  $STD systemctl enable --now unattended-upgrades || true
  msg_ok "Enabled unattended-upgrades"
}
register_event_handler post_install proxmox_post_install

installer_run "$@"
