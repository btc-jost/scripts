#!/usr/bin/env bash
#
# btc Helper Scripts - Zabbix Agent 2 Installation Script
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

ZABBIX_VERSION="8.0"

zabbix_agent2_preinstall() {
  # Install Zabbix repository
  if [ -f /etc/os-release ]; then
    local PACKAGE_NAME=""

    source /etc/os-release

    # Check for Raspbian
    if [ "$ID" == "raspbian" ]; then
      PACKAGE_NAME="zabbix-release_latest_${ZABBIX_VERSION}+${ID_LIKE}${VERSION_ID}_all.deb"
    else
      PACKAGE_NAME="zabbix-release_latest_${ZABBIX_VERSION}+${ID}${VERSION_ID}_all.deb"
    fi

    PACKAGE_URL="https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/release/${ID}/pool/main/z/zabbix-release/${PACKAGE_NAME}"

    wget "${PACKAGE_URL}"
    dpkg -i "${PACKAGE_NAME}"

    apt update

    # Clean up
    rm "${PACKAGE_NAME}"
  fi
}

# Install Zabbix agent 2
apt install zabbix-agent2 -y

# Configure Zabbix agent 2
echo -e 'Server=192.168.72.5\nServerActive=192.168.72.5\nHostname=' > /etc/zabbix/zabbix_agent2.d/smart_monitoring.conf

# Enable and start Zabbix agent 2 service
systemctl restart zabbix-agent2
systemctl enable zabbix-agent2
