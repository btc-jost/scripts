#!/bin/bash

# Post-installation script for 3CX on Debian

# Install Zabbix repository
wget https://repo.zabbix.com/zabbix/7.4/release/debian/pool/main/z/zabbix-release/zabbix-release_latest_7.4+debian12_all.deb
dpkg -i zabbix-release_latest_7.4+debian12_all.deb
apt update

# Clean up
rm zabbix-release_latest_7.4+debian12_all.deb

# Install Zabbix agent 2
apt install zabbix-agent2 -y

# Configure Zabbix agent 2
echo -e 'Server=192.168.72.5\nServerActive=192.168.72.5\nHostname=' > /etc/zabbix/zabbix_agent2.d/smart_monitoring.conf

# Enable and start Zabbix agent 2 service
systemctl stop zabbix-agent2
systemctl enable zabbix-agent2
systemctl start zabbix-agent2

# Install chrony for time synchronization
apt install chrony -y

# Configure chrony to use Swiss NTP servers
echo -e 'pool 0.ch.pool.ntp.org iburst\npool 1.ch.pool.ntp.org iburst\npool 2.ch.pool.ntp.org iburst\npool 3.ch.pool.ntp.org iburst' > /etc/chrony/sources.d/pool-ntp-org.sources

# Reload sources to apply changes
chronyc reload sources

# Final message
echo "Post-installation script completed."
