#!/usr/bin/env bash
#
# btc Helper Scripts - local dry-run test harness
#
# Runs an installer/composite against the LOCAL framework libs WITHOUT touching
# the system: apt/systemctl/dpkg/wget and the side-effectful tools.func helpers
# are stubbed, and config writes are redirected under a throwaway directory.
# Use it to verify event ordering, the batched package install, grouped service
# restart, prompt defaults and composition — none of which need root or Debian.
#
# Usage:
#   bash tests/harness.sh <script> [mode]
#   CUSTOMER=acme LOCATION=zrh bash tests/harness.sh zabbix/install-sm-proxy.sh install
#
#   <script>  path (repo-relative) to an installer or composite, e.g.
#             installer/chrony.sh, installer/zabbix-agent2.sh,
#             zabbix/install-sm-proxy.sh, 3cx/post-install.sh
#   [mode]    install (default) | update | remove
#
# Answers: questions without a declared default (e.g. CUSTOMER/LOCATION) can be
# supplied as environment variables; declared defaults fill the rest.
#
# For a REAL run, do NOT use this harness — run the script as root on a Debian/
# Ubuntu box (or WSL2), e.g.  sudo bash installer/chrony.sh install
# ------------------------------------------------------------------------------
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

TARGET="${1:?usage: bash tests/harness.sh <script> [mode]}"
MODE="${2:-install}"

# --- source the LOCAL libs (load guards turn the scripts' wget lines into no-ops)
source framework/core.func
source framework/prompt.func
source framework/tools.func
source framework/installer.func

# include_installer resolves siblings from the local checkout
export INSTALLER_LOCAL_DIR="${REPO_ROOT}/installer"
export VERBOSE="${VERBOSE:-yes}"
export UNATTENDED=yes

# --- throwaway target tree for config writes ---------------------------------
DRYROOT="$(mktemp -d 2>/dev/null || echo /tmp/btc-dryrun)"
mkdir -p "$DRYROOT"
export _AGENT_CONF="${DRYROOT}/agent2.conf"
export _PROXY_CONF="${DRYROOT}/proxy.conf"
export _CHRONY_NTP_FILE="${DRYROOT}/chrony.sources"
export ZBX_PSK_FILE="${DRYROOT}/psk.key"
export ZBX_DB_PATH="${DRYROOT}/zabbix-proxy.db"

# --- stub system mutations and external helpers ------------------------------
apt-get() { echo "    [apt-get $*]"; }
systemctl() { echo "    [systemctl $*]"; }
dpkg() { echo "    [dpkg $*]"; }
wget() { echo "    [wget $*]" >&2; }
chronyc() { echo "    [chronyc $*]"; }
openssl() { echo "DRYRUN-PSK-$(date +%s)"; }
chown() { :; }
hostname() { echo "dryrun-host"; }
root_check() { :; }
shell_check() { :; }

# tools.func helpers that need /etc, network or a real repo: stub but keep the
# idempotency guard so composition behaviour is still exercised.
_repo_calls=0
setup_zabbix_repo() {
  [[ -n "${_ZBX_REPO_DONE:-}" ]] && return 0
  _repo_calls=$((_repo_calls + 1))
  echo "    [setup_zabbix_repo version=${ZABBIX_VERSION:-?}] (call #${_repo_calls})"
  _ZBX_REPO_DONE=1
}
configure_swiss_ntp() {
  echo "    [configure_swiss_ntp -> ${_CHRONY_NTP_FILE}]"
  printf 'pool 0.ch.pool.ntp.org iburst\n' >"${_CHRONY_NTP_FILE}"
}

# Honour env-provided answers; fill the rest from declared defaults.
run_questions() {
  local i key
  for i in "${!_Q_KEYS[@]}"; do
    key="${_Q_KEYS[$i]}"
    [[ -z "${!key:-}" ]] && _q_apply_default "$i"
  done
}

echo "=== dry-run: ${TARGET} ${MODE} (DRYROOT=${DRYROOT}) ==="
# shellcheck disable=SC1090
source "${TARGET}" "${MODE}"

echo
echo "=== artifacts under ${DRYROOT} ==="
for f in "$DRYROOT"/*; do
  [[ -e "$f" ]] || continue
  echo "--- ${f##*/} ---"
  cat "$f"
done
echo
echo "(repo setup invoked ${_repo_calls}x — should be 1 even when several zabbix units compose)"
