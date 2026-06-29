#!/usr/bin/env bash
#
# btc Helper Scripts - local dry-run test harness
#
# Runs a component/composite against the LOCAL framework libs WITHOUT touching
# the system: apt/systemctl/dpkg/wget and the side-effectful tool helpers
# are stubbed, and config writes are redirected under a throwaway directory.
# Use it to verify event ordering, the batched package install, grouped service
# restart, prompt defaults and composition — none of which need root or Debian.
#
# Usage:
#   bash tests/harness.sh <script> [mode]
#   SM_PROXY__CUSTOMER=acme SM_PROXY__LOCATION=zrh bash tests/harness.sh zabbix/install-sm-proxy.sh install
#
#   <script>  path (repo-relative) to a component or composite, e.g.
#             component/chrony.sh, component/zabbix-agent2.sh,
#             zabbix/install-sm-proxy.sh, 3cx/post-install.sh
#   [mode]    install (default) | update | remove
#
# Answers: questions without a declared default (e.g. SM_PROXY__CUSTOMER/SM_PROXY__LOCATION) can be
# supplied as environment variables; declared defaults fill the rest.
#
# For a REAL run, do NOT use this harness — run the script as root on a Debian/
# Ubuntu box (or WSL2), e.g.  sudo bash component/chrony.sh install
# ------------------------------------------------------------------------------
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

TARGET="${1:?usage: bash tests/harness.sh <script> [mode]}"
MODE="${2:-install}"

# --- source the LOCAL libs directly, in dependency order. Once their load
# guards are set, the wget-based source lines inside component.func/composite.func
# (and the target scripts) become no-ops, so nothing hits the network.
source framework/core.func
source framework/engine.func
source framework/prompt.func
source framework/component.func
source framework/composite.func

# include_component resolves siblings from the local checkout
export COMPONENT_LOCAL_DIR="${REPO_ROOT}/component"
export VERBOSE="${VERBOSE:-yes}"
export UNATTENDED=yes

# --- throwaway target tree for config writes ---------------------------------
DRYROOT="$(mktemp -d 2>/dev/null || echo /tmp/btc-dryrun)"
mkdir -p "$DRYROOT"
export _ZABBIX_AGENT2__CONF="${DRYROOT}/agent2.conf"
export _ZABBIX_PROXY__CONF="${DRYROOT}/proxy.conf"
export _CHRONY__NTP_FILE="${DRYROOT}/chrony.sources"
export _ZABBIX_PROXY__PSK_FILE="${DRYROOT}/psk.key"
export _ZABBIX_PROXY__DB_PATH="${DRYROOT}/zabbix-proxy.db"
export _PKG_STATE_FILE="${DRYROOT}/installed-packages"
export LOGFILE="${DRYROOT}/run.log" # keep silent()'s log out of /var/log in tests

# Simulated dpkg state so ownership tracking is exercised: apt-get install/purge
# mutate it and dpkg-query reads it. Seed PRE_INSTALLED="pkg1 pkg2" to pretend some
# packages already exist (they must then survive a remove).
_INSTALLED_DB="${DRYROOT}/.installed"
# shellcheck disable=SC2086  # intentional word-split: one package per line
printf '%s\n' ${PRE_INSTALLED:-} >"$_INSTALLED_DB"

# --- stub system mutations and external helpers ------------------------------
apt-get() {
  echo "    [apt-get $*]"
  local sub="$1" a only_upgrade=0 tmp
  shift || true
  case "$sub" in
    install)
      for a in "$@"; do [[ "$a" == "--only-upgrade" ]] && only_upgrade=1; done
      for a in "$@"; do
        [[ "$a" == -* ]] && continue
        grep -qxF "$a" "$_INSTALLED_DB" && continue
        [[ $only_upgrade -eq 1 ]] && continue # --only-upgrade won't install missing
        echo "$a" >>"$_INSTALLED_DB"
      done
      ;;
    purge)
      tmp="$(mktemp)"; cp "$_INSTALLED_DB" "$tmp"
      for a in "$@"; do
        [[ "$a" == -* ]] && continue
        grep -vxF "$a" "$tmp" >"${tmp}.2" 2>/dev/null && mv "${tmp}.2" "$tmp"
      done
      mv "$tmp" "$_INSTALLED_DB"
      ;;
  esac
}
systemctl() { echo "    [systemctl $*]"; }
dpkg() { echo "    [dpkg $*]"; }
dpkg-query() { # ... <pkg> (last arg); print Status + succeed if "installed"
  local pkg="${!#}"
  grep -qxF "$pkg" "$_INSTALLED_DB" && { echo "install ok installed"; return 0; }
  return 1
}
wget() { echo "    [wget $*]" >&2; }
chronyc() { echo "    [chronyc $*]"; }
openssl() { echo "DRYRUN-PSK-$(date +%s)"; }
chown() { :; }
hostname() { echo "dryrun-host"; }
root_check() { :; }
shell_check() { :; }

# The Zabbix repo is now the zabbix-release component: its pre_install runs through the
# wget/dpkg/apt-get stubs above and records zabbix-release ownership (visible in the
# ownership artifact). include_component's dedup ensures it runs once per composite.

# Answers without a declared default (e.g. SM_PROXY__CUSTOMER/SM_PROXY__LOCATION) are supplied as env
# vars; the real run_questions (unattended) then skips them as already-set and
# fills declared defaults for the rest.

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
echo "(the ownership artifact should list zabbix-release once, even when several zabbix units compose)"
