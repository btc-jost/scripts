#!/bin/bash

# Post-installation script for 3CX on Debian

# Install and configure chrony for time synchronization
apt update
apt install chrony -y

# Configure chrony to use Swiss NTP servers
echo -e 'pool 0.ch.pool.ntp.org iburst\npool 1.ch.pool.ntp.org iburst\npool 2.ch.pool.ntp.org iburst\npool 3.ch.pool.ntp.org iburst' > /etc/chrony/sources.d/pool-ntp-org.sources

# Reload sources to apply changes
chronyc reload sources
