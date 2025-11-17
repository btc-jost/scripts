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

source <(wget -qO- https://raw.githubusercontent.com/btc-jost/scripts/main/misc/installer.func)

CHRONY_NTP_SERVERS=()
_CHRONY_NTP_FILE="/etc/chrony/sources.d/pool-ntp-org.sources"

configure_chrony() {
  # NTP Server Configuration
  local choice=$(whiptail --backtitle ${TITLE} --title "${APP} LXC Update/Setting" --menu \
    "Support/Update functions for ${APP} LXC. Choose an option:" \
    12 60 3 \
    "1" "Swiss NTP server pool" \
    "2" "User defined" \
    "3" "NO (Cancel Update)" --nocancel --default-item "1" 3>&1 1>&2 2>&3)

  case "$choice" in
  1)
    CHRONY_NTP_SERVERS=(
      "0.ch.pool.ntp.org iburst"
      "1.ch.pool.ntp.org iburst"
      "2.ch.pool.ntp.org iburst"
      "3.ch.pool.ntp.org iburst"
    )
    ;;
  2)
    CHRONY_NTP_SERVERS=()
    while true; do
      local ntp_server=$(whiptail --backtitle ${TITLE} --inputbox "Enter NTP server. Leave empty to finish." 10 60 3>&1 1>&2 2>&3)

      if [ -z "$ntp_server" ]; then
        break
      fi

      CHRONY_NTP_SERVERS+=("$ntp_server iburst")
    done
    ;;
  3)
    clear
    exit_script
    exit
    ;;
  esac
}

pre_install_chrony() {

}

install_chrony() {
  add_packages "chrony"
}

post_install_chrony() {
  # Configure NTP servers
  IFSBACKUP=$IFS
  IFS=$'\n'
  echo ${CHRONY_NTP_SERVERS[*]} > $_CHRONY_NTP_FILE
  IFS=$IFSBACKUP

  #echo -e 'pool 0.ch.pool.ntp.org iburst\npool 1.ch.pool.ntp.org iburst\npool 2.ch.pool.ntp.org iburst\npool 3.ch.pool.ntp.org iburst' > /etc/chrony/sources.d/pool-ntp-org.sources

  # Reload sources to apply changes
  chronyc reload sources
}

pre_update_chrony() {

}

update_chrony() {

}

post_update_chrony() {

}

pre_remove_chrony() {

}

remove_chrony() {

}

post_remove_chrony() {

}

register_event_handler "configure" "configure_chrony"
register_event_handler "pre_install" "pre_install_chrony"
register_event_handler "install" "install_chrony"
register_event_handler "post_install" "post_install_chrony"
register_event_handler "pre_update" "pre_update_chrony"
register_event_handler "update" "update_chrony"
register_event_handler "post_update" "post_update_chrony"
register_event_handler "pre_remove" "pre_remove_chrony"
register_event_handler "remove" "remove_chrony"
register_event_handler "post_remove" "post_remove_chrony"

installer_run $@
