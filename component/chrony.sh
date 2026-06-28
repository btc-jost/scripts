#!/usr/bin/env bash
#
# btc Helper Scripts - Chrony Installation Script
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

_CHRONY__NTP_FILE="${_CHRONY__NTP_FILE:-/etc/chrony/sources.d/pool-ntp-org.sources}"

add_packages chrony
add_services chronyd
register_question CHRONY__SOURCE menu "Select the NTP time source" default=swiss \
  "swiss=Swiss NTP server pool" \
  "custom=User defined servers"
register_question CHRONY__CUSTOM input_list "Enter an NTP server (leave empty to finish)" \
  when=CHRONY__SOURCE=custom
register_event_handler post_install chrony_post_install

chrony_post_install() {
  local sources=()
  if [[ "${CHRONY__SOURCE:-swiss}" == "custom" && ${#CHRONY__CUSTOM[@]} -gt 0 ]]; then
    local s
    for s in "${CHRONY__CUSTOM[@]}"; do
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
  mkdir -p "$(dirname "$_CHRONY__NTP_FILE")"
  printf '%s\n' "${sources[@]}" >"$_CHRONY__NTP_FILE"
  $STD chronyc reload sources || true
  msg_ok "Configured NTP sources"
}

installer_run "$@"
