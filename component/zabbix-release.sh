#!/usr/bin/env bash
#
# btc Helper Scripts - Zabbix Release / Repository Component
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

# Contract vars (set before include_component): ZABBIX_VERSION.
ZABBIX_VERSION="${ZABBIX_VERSION:-7.4}"

set_app_id zabbix-release
# zabbix-release is in APP_PACKAGES so the engine's batched apt step installs/owns it and
# `remove` purges it. pre_install only bootstraps the repo (dpkg -i the release deb) when
# it isn't already present, recording ownership right away so the install hint and removal
# stay accurate.
add_package zabbix-release
register_event_handler pre_install zabbix_release_pre_install

# ------------------------------------------------------------------------------
# _version_ge <a> <b> - return 0 if version a >= version b (dotted compare).
# ------------------------------------------------------------------------------
_version_ge() {
  [[ "$1" == "$2" ]] && return 0
  local lowest
  lowest="$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)"
  [[ "$lowest" == "$2" ]]
}

# ------------------------------------------------------------------------------
# zabbix_release_pre_install - add the Zabbix apt repository for $ZABBIX_VERSION.
#
# Reads ZABBIX_VERSION (e.g. "7.0", "8.0") and /etc/os-release. The repo layout
# changed at 7.2: older releases live under /zabbix/<ver>/<id>/, newer ones under
# /zabbix/<ver>/release/<id>/. The "latest_<ver>+" filename exists in both.
# Verified against repo.zabbix.com (7.0 debian, 8.0 release/debian).
#
# If zabbix-release is already installed (pre-existing repo), keep it untouched and
# unowned (remove leaves it). Otherwise bootstrap via dpkg -i and own it.
# ------------------------------------------------------------------------------
zabbix_release_pre_install() {
  if pkg_installed zabbix-release; then
    msg_note "Zabbix repository already present (zabbix-release installed); keeping it"
    return 0
  fi

  local version="${ZABBIX_VERSION:?ZABBIX_VERSION must be set}"
  local ID VERSION_ID
  # shellcheck disable=SC1091
  . /etc/os-release

  local base
  if _version_ge "$version" "7.2"; then
    base="https://repo.zabbix.com/zabbix/${version}/release/${ID}"
  else
    base="https://repo.zabbix.com/zabbix/${version}/${ID}"
  fi
  local deb="zabbix-release_latest_${version}+${ID}${VERSION_ID}_all.deb"
  local url="${base}/pool/main/z/zabbix-release/${deb}"

  msg_info "Adding Zabbix ${version} repository"
  local tmp
  tmp="$(mktemp -d)"
  if $STD wget -O "${tmp}/${deb}" "$url" && $STD dpkg -i "${tmp}/${deb}"; then
    $STD apt-get update || true
    rm -rf "$tmp"
    own_package zabbix-release
    msg_ok "Added Zabbix ${version} repository"
  else
    rm -rf "$tmp"
    msg_error "Failed to add Zabbix repository from ${url}"
    return 1
  fi
}

installer_run "$@"
