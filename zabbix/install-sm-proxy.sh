#!/bin/bash

# Installation script for smartMonitoring proxy on Debian or Ubuntu

# Initialize variables
ZABBIX_VERSION="7.0"
HOSTNAME=""

# ------------------------------------------------------------------------------
# exit_script()
#
# - Called when user cancels an action
# - Clears screen and displays exit message
# - Exits with default exit code
# ------------------------------------------------------------------------------
exit_script() {
  #clear
  #msg_error "User exited script"
  echo "User exited script"
  exit 0
}

# ------------------------------------------------------------------------------
# settings()
#
# - Interactive wizard-style configuration with BACK navigation
# - State-machine approach: each step can go forward or backward
# - Cancel at Step 1 = Exit Script, Cancel at other steps = Go Back
# - Allows user to customize all proxy settings
# ------------------------------------------------------------------------------
settings() {
  # Enter alternate screen buffer to prevent flicker between dialogs
  tput smcup 2>/dev/null || true
  trap 'tput rmcup 2>/dev/null || true' RETURN

  # Initialize defaults
  local STEP=1
  local MAX_STEP=3

  # Store values for back navigation
  local _customer=""
  local _location=""

  # Main wizard loop
  while [ $STEP -le $MAX_STEP ]; do
    case $STEP in

    # ═══════════════════════════════════════════════════════════════════════════
    # STEP 1: Customer name
    # ═══════════════════════════════════════════════════════════════════════════
    1)
      if result=$(whiptail --backtitle "btc Helper Scripts [Step $STEP/$MAX_STEP]" \
        --title "CUSTOMER NAME" \
        --ok-button "Next" --cancel-button "Exit" \
        --inputbox "\nSet Customer Name" 10 58 "$_customer" \
        3>&1 1>&2 2>&3); then

        # allow only alphanumeric characters (no spaces or special chars) for hostname compatibility
        if ! [[ $result =~ ^[[:alnum:]]+$ ]]; then
          whiptail --backtitle "btc Helper Scripts" --title "Invalid Customer Name" --msgbox "Customer name can only contain letters and numbers (no spaces or special characters)." 8 58
          continue
        fi

        _customer="$result"

        ((STEP++))
      else
        exit_script
      fi
      ;;

    # ═══════════════════════════════════════════════════════════════════════════
    # STEP 2: Location
    # ═════════════════════════════════════════════════════════════════════════
    2)
      if result=$(whiptail --backtitle "btc Helper Scripts [Step $STEP/$MAX_STEP]" \
        --title "LOCATION" \
        --ok-button "Next" --cancel-button "Back" \
        --inputbox "\nSet Location" 10 58 "$_location" \
        3>&1 1>&2 2>&3); then

        # allow only alphanumeric characters (no spaces or special chars) for hostname compatibility
        if ! [[ $result =~ ^[[:alnum:]]+$ ]]; then
          whiptail --backtitle "btc Helper Scripts" --title "Invalid Location" --msgbox "Location can only contain letters and numbers (no spaces or special characters)." 8 58
          continue
        fi

        _location="$result"

        ((STEP++))
      else
        ((STEP--))
      fi
      ;;

    # ═══════════════════════════════════════════════════════════════════════════
    # STEP 3: Verbose Mode & Confirmation
    # ═══════════════════════════════════════════════════════════════════════════
    3)
      local verbose_default_flag="--defaultno"
      [[ "$_verbose" == "yes" ]] && verbose_default_flag=""

      if whiptail --backtitle "btc Helper Scripts [Step $STEP/$MAX_STEP]" \
        --title "VERBOSE MODE" \
        $verbose_default_flag \
        --yesno "\nEnable Verbose Mode?\n\nShows detailed output during installation." 12 58; then
        _verbose="yes"
      else
        _verbose="no"
      fi

      # Build summary
      local summary="Customer: $_customer
Location: $_location

Advanced:
  Verbose: $_verbose"

      if whiptail --backtitle "btc Helper Scripts [Step $STEP/$MAX_STEP]" \
        --title "CONFIRM SETTINGS" \
        --ok-button "Create LXC" --cancel-button "Back" \
        --yesno "$summary\n\nCreate SmartMonitoring Proxy with these settings?" 32 62; then
        ((STEP++))
      else
        ((STEP--))
      fi
      ;;
    esac
  done

  # ═══════════════════════════════════════════════════════════════════════════
  # Apply all collected values to global variables
  # ═══════════════════════════════════════════════════════════════════════════
  HOSTNAME="${_customer,,}-proxy-${_location,,}"

  # Exit alternate screen buffer before showing summary (so output remains visible)
  tput rmcup 2>/dev/null || true
  trap - RETURN

  # Display final summary
  echo -e "\n${INFO}${BOLD}${DGN}Zabbix Proxy Version ${ZABBIX_VERSION}${CL}"
  echo -e "${OS}${BOLD}${DGN}Operating System: ${BGN}$PRETTY_NAME${CL}"
}

# Load OS information for use in repository URL construction
# shellcheck disable=SC1091
. /etc/os-release

# Configure proxy
settings

# Install Zabbix repository
wget "https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/${ID}/pool/main/z/zabbix-release/zabbix-release_latest+${ID}${VERSION_ID}_all.deb"
dpkg -i "zabbix-release_latest+${ID}${VERSION_ID}_all.deb"
apt update

# Clean up
rm "zabbix-release_latest+${ID}${VERSION_ID}_all.deb"

# Install Zabbix proxy, agent 2, and chrony
apt install zabbix-proxy-sqlite3 zabbix-agent2 chrony openssl -y

# Configure Zabbix agent 2
echo -e "Hostname=${HOSTNAME}" > /etc/zabbix/zabbix_agent2.d/smartmonitoring.conf

if [ -f /etc/zabbix/psk.key ]; then
    echo "PSK key already exists. Skipping generation."
else
    openssl rand -hex 256 > /etc/zabbix/psk.key
fi

echo -e "Server=monitoring.smartcollab.ch\nHostname=${HOSTNAME}\nDBName=/var/lib/sqlite/zabbix-proxy.db\nTLSConnect=psk\nTLSAccept=psk\nTLSPSKIdentity=${HOSTNAME}\nTLSPSKFile=/etc/zabbix/psk.key" >> /etc/zabbix/zabbix_proxy.d/smartmonitoring.conf

mkdir -p /var/lib/sqlite
chown zabbix:zabbix /var/lib/sqlite

# Enable and start Zabbix agent 2 service
systemctl enable zabbix-proxy zabbix-agent2
systemctl restart zabbix-proxy zabbix-agent2

# Configure chrony to use Swiss NTP servers
echo -e 'pool 0.ch.pool.ntp.org iburst\npool 1.ch.pool.ntp.org iburst\npool 2.ch.pool.ntp.org iburst\npool 3.ch.pool.ntp.org iburst' > /etc/chrony/sources.d/pool-ntp-org.sources

# Reload sources to apply changes
chronyc reload sources

# Final message
echo -e "\nPost-installation script completed."
echo -e "\nProxy hostname:\n${HOSTNAME}"
echo -e "\nPSK key:\n$(cat /etc/zabbix/psk.key)"
echo -e "\nPlease add the PSK key to the configuration and ensure the proxy is communicating with the Zabbix server."
