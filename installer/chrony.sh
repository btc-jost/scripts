#!/usr/bin/env bash
#
# btc Helper Scripts - Chrony Installation Script
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

_CHRONY_NTP_FILE="${_CHRONY_NTP_FILE:-/etc/chrony/sources.d/pool-ntp-org.sources}"

# Reusable unit: opt this component in by calling chrony_register.
chrony_register() {
  add_packages chrony
  add_service chronyd
  register_question NTP_SOURCE menu "Select the NTP time source" default=swiss \
    "swiss=Swiss NTP server pool" \
    "custom=User defined servers"
  register_question NTP_CUSTOM input_list "Enter an NTP server (leave empty to finish)" \
    when=NTP_SOURCE=custom
  register_event_handler post_install chrony_post_install
}

chrony_post_install() {
  local sources=()
  if [[ "${NTP_SOURCE:-swiss}" == "custom" && ${#NTP_CUSTOM[@]} -gt 0 ]]; then
    local s
    for s in "${NTP_CUSTOM[@]}"; do
      sources+=("server ${s} iburst")
    done
  else
    sources=(
      "pool 0.ch.pool.ntp.org iburst"
      "pool 1.ch.pool.ntp.org iburst"
      "pool 2.ch.pool.ntp.org iburst"
      "pool 3.ch.pool.ntp.org iburst"
    )
  fi

  msg_info "Configuring NTP sources"
  mkdir -p "$(dirname "$_CHRONY_NTP_FILE")"
  printf '%s\n' "${sources[@]}" >"$_CHRONY_NTP_FILE"
  $STD chronyc reload sources || true
  msg_ok "Configured NTP sources"
}

# Standalone entrypoint (skipped when included via include_installer).
if [[ -z "${_COMPOSING:-}" ]]; then
  APP="${APP:-Chrony}"
  chrony_register
  installer_run "$@"
fi
