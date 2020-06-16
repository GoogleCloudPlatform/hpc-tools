#!/bin/bash
# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# MPI tuning script
# This script applies different system tunings for getting better performance
# for MPI application.
# This script is validated on GCP CentOS 7 image only

# catch SIGEXIT and SIGINT
trap 'cleanup' EXIT
trap 'LOG "interrupted, cleaning up..."; cleanup' INT

readonly TUNED_PROFILE="network-latency"
readonly NIC="eth0"
readonly SYSCTL_CONF="/etc/sysctl.conf"
readonly LIMITS_CONF="/etc/security/limits.conf"
readonly GRUB_DEFAULT="/etc/default/grub"
readonly SELINUX_CONFIG="/etc/selinux/config"
GRUB_FILE="/boot/grub2/grub.cfg"

verbose=false

task_all=0 # run all tasks (unsafe)
task_tcpmem=0 # tcpmem
task_tuned=0 # tuned_adm
task_limits=0 # limits.conf
task_ht=0 # hyperthreading
task_firewall=0 # firewall
task_selinux=0 # selinux
task_mitigations=0 # CPU mitigations
task_reboot=0 # reboot system if necessary

need_reboot=0
dryrun=0

LOG()
{
  if [[ ${dryrun} = 0 ]]; then
    printf "%s\n" "$*" >&2
  else
    printf "# %s\n" "$*" >&2
  fi
}

# LOGV prints only if verbose is set.
LOGV()
{
  ${verbose} && LOG "$*"
}

IN_ERROR=false
# ERROR prints the error and exit.
ERROR()
{
  ${IN_ERROR} && return
  IN_ERROR=true
  LOG "Error: $*"
  exit 1
}

# clean up
cleanup()
{
  trap - INT EXIT
  if [[ "$need_reboot" = 1 ]]; then
    if [[ "$IN_ERROR" = "true" ]]; then
      echo "Execution aborted, reboot pending"
      exit 1
    fi

    if [[ "$task_reboot" = 1 ]]; then
      LOG "Reboot required"

      if [[ "$dryrun" = 1 ]]; then
        echo "systemctl reboot"
        exit 0
      fi
      echo "Reboot in 10 seconds (^C to cancel) ..."
      sleep 10
      systemctl reboot
    else
      LOG "Reboot required, please manually reboot your system"
    fi
  fi
}

# check if task(s) were selected
check_task()
{
  [[ $task_all -gt 0 ]] && LOG "Selecting all tasks." && return

  [[ "$task_tcpmem" = 0 ]] && [[ "$task_tuned" = 0 ]] && \
    [[ "$task_limits" = 0 ]] && [[ "$task_ht" = 0 ]] && [[ "$task_firewall" = 0 ]] && \
    [[ "$task_selinux" = 0 ]] && [[ "$task_mitigations" = 0 ]] &&\
    LOG "No task(s) selected." && show_usage && exit 1
}

# check if running as root
check_root()
{
  [[ "$EUID" -ne 0 ]] && ERROR "Please run this script as root"
}

# check dependencies
check_bin()
{
  local readonly deps="ethtool tuned-adm lscpu"
  fail=false

  for bin in $deps; do
    LOGV "Check dependency: $bin"
    binpath=$(command -v "$bin")
    if [[ -z $binpath ]]; then
      LOG "$bin not found"
      fail=true
    fi
  done

  ${fail} && ERROR "Please install missing dependencies"
}

# check centos release version
# allow --dryrun for non-centos 7 system
check_centos()
{
  local centos_major

  centos_major=$(rpm --eval %{centos_ver})

  if [[ ! $centos_major = 7 ]]; then
    if [[ "$dryrun" = 1 ]]; then
      LOG "This script is only validated on CentOS 7."
    else
      ERROR "This script is only validated on CentOS 7."
    fi
  fi
}

run() {
  if [[ "$dryrun" = 1 ]]; then
    echo "$*"
  else
    eval "$*"
  fi
}


update_sysctl()
{
  local key=$1
  shift
  local value=$*
  LOGV "Updating sysctl key=$key, value=$value"
  touch $SYSCTL_CONF
  local regex="'s/^\s*$key\s*=.*$/$key = $value/g'"
  run sed -i "$regex" "$SYSCTL_CONF"
  if ! grep -Fq "$key" "$SYSCTL_CONF"; then
    LOGV "sysctl $key not found, appending to $SYSCTL_CONF"
    run echo "$key = $value" ">>" $SYSCTL_CONF
  fi
}

update_grub_default()
{
  local key=$1
  shift
  local value=$*
  if grep -Eq '^GRUB_CMDLINE_LINUX.*'"$key" $GRUB_DEFAULT; then
    LOGV "Found boot parameter: $key"
    return 1
  else
    LOGV "Adding boot parameter: $key"
    local regex="'s/GRUB_CMDLINE_LINUX=\"[^\"]*/& '$key'/'"
    run sed -i "$regex" $GRUB_DEFAULT
  fi
}

update_grub_config()
{
  LOGV "Updating grub config"
  run grub2-mkconfig -o $GRUB_FILE
}

update_limits()
{
  local item=$1
  local value=$2
  LOGV "Updating limits item=$item, value=$value"
  local line="\*    -    $item    $value"
  local regex="'/^\s*\*.+'$item'.*$/d'"
  run sed -Ei "$regex" $LIMITS_CONF
  run echo "$line" ">>" $LIMITS_CONF
}

test_reboot()
{
  [[ -n "$need_reboot" ]] && return
}

show_usage()
{
  cat <<EOF
  Usage:
    Verify tuning steps: $(basename "$0") [options] --dryrun
    Apply tunings: $(basename "$0") [options]

  Options:
    --tcpmem           Increase memory for TCP
    --networklatency   Enable busy polling and low network latency profile
    --limits           Change the system ulimits
    --nosmt            Disable simultaneous multi threading (reboot required)
    --nofirewalld      Disable firewalld
    --noselinux        Disable SE Linux (reboot required)
    --nomitigation     Disable CPU vulnerabilities mitigations (reboot required)
    --reboot           Reboot system after tunings if required
    --dryrun           Do not execute commands
    --verbose          Print verbose messages
    --help             Show help message
EOF
}

get_phy_cpus() {
  # get physical core count
  nr_cpus=$(lscpu -p | grep -v '^#' | sort -t, -k 2,4 -u | wc -l)
  LOGV "Found $nr_cpus physical cores"
}

# Update GRUB_FILE for UEFI systems (require check_root)
get_grub_cfg() {
  local grubconf

  # verify if boot in UEFI mode
  if [[ -d /sys/firmware/efi ]]; then
    LOGV "System booted in UEFI mode"
    grubconf=$(readlink -e /etc/grub2-efi.cfg)
  else
    LOGV "System booted in BIOS mode"
    grubconf=$(readlink -e /etc/grub2.cfg)
  fi

  if [[ ! -z "$grubconf" ]]; then
    LOGV "Location of grub.cfg: $grubconf"
    GRUB_FILE=$grubconf
  fi
}

tune_tcpmem() {
  LOG "Updating sysctl: TCP memory"
  update_sysctl net.ipv4.tcp_rmem 4096 87380 16777216
  update_sysctl net.ipv4.tcp_wmem 4096 16384 16777216
  sysctl -p
}

tune_networklatency() {
  LOG "Running tuned-adm"
  run tuned-adm profile $TUNED_PROFILE
}

tune_nicqueue() {
  LOG "Tunning NIC queues"

  local driver
  local hw_queues

  # get nic driver
  driver=$(ethtool -i $NIC | grep driver | cut -d':' -f2 | xargs)

  # get max queue count
  hw_queues=$(ethtool -l ${NIC} | grep -A4 maximums | tail -n 1 | cut -d':' -f2)
  LOGV "NIC $NIC supports up to $hw_queues combined queues"


  if [[ ! "$driver" == "virtio_net" ]]; then
    LOG "Skipped: $NIC is not a virtio-net NIC"
    return
  fi

  local queues=$(( $nr_cpus > $hw_queues ? $hw_queues : $nr_cpus))
  LOGV "Applying $queues queues"
  run ethtool -L $NIC combined $queues
}

tune_limits() {
  LOG "Applying limit.conf"
  update_limits nproc unlimited
  update_limits memlock unlimited
  update_limits stack unlimited
  update_limits nofile 1048576
  update_limits cpu unlimited
  update_limits rtprio unlimited
  run ulimit -a
}

tune_ht()
{
  LOG "Disabling hyperthreading"
  local grub_updated=0
  update_grub_default noht && grub_updated=1
  update_grub_default nosmt && grub_updated=1
  update_grub_default nr_cpus="$nr_cpus" && grub_updated=1
  if [[ $grub_updated ]]; then
    update_grub_config
    need_reboot=1
  fi
}

tune_selinux()
{
  LOG "Disabling SELinux"
  run sed -i 's/^SELINUX=.*$/SELINUX=disabled/g' $SELINUX_CONFIG
  need_reboot=1
}

tune_firewall()
{
  LOG "Disabling firewall"
  run "systemctl stop firewalld > /dev/null"
  run "systemctl disable firewalld > /dev/null"
  run "systemctl mask --now firewalld > /dev/null"
}

tune_mitigations()
{
  LOG "Disabling CPU mitigations"
  local grub_updated=0
  update_grub_default spectre_v2=off && grub_updated=1
  update_grub_default nopti && grub_updated=1
  update_grub_default spec_store_bypass_disable=off
  if [[ $grub_updated ]]; then
    update_grub_config
    need_reboot=1
  fi
}


# main routine
while [[ "$1" =~ "--" ]]; do
  if [[ "$1" = "--verbose" ]]; then
    verbose=true
    shift
    continue
  elif [[ "$1" = "--help" ]] || [[ "$1" = "-h" ]]; then
    show_usage
    exit 0
  elif [[ "$1" = "--tcpmem" ]]; then
    task_tcpmem=1
    shift
    continue
  elif [[ "$1" = "--networklatency" ]]; then
    task_tuned=1
    shift
    continue
  elif [[ "$1" = "--limits" ]]; then
    task_limits=1
    shift
    continue
  elif [[ "$1" = "--nosmt" ]]; then
    task_ht=1
    shift
    continue
  elif [[ "$1" = "--nofirewalld" ]]; then
    task_firewall=1
    shift
    continue
  elif [[ "$1" = "--noselinux" ]]; then
    task_selinux=1
    shift
    continue
  elif [[ "$1" = "--nomitigation" ]]; then
    task_mitigations=1
    shift
    continue
  elif [[ "$1" = "--reboot" ]]; then
    task_reboot=1
    shift
    continue
  elif [[ "$1" = "--dryrun" ]]; then
    dryrun=1
    shift
    continue
  else
    LOG "Unrecognized option $1"
    show_usage
    exit 0
  fi
done

check_task
check_bin
check_centos
get_phy_cpus
check_root
get_grub_cfg

[[ "$task_all" = 1 || "$task_tcpmem" = 1 ]] && tune_tcpmem
[[ "$task_all" = 1 || "$task_tuned" = 1 ]] && tune_networklatency
[[ "$task_all" = 1 || "$task_limits" = 1 ]] && tune_limits
[[ "$task_all" = 1 || "$task_ht" = 1 ]] && tune_ht
[[ "$task_all" = 1 || "$task_selinux" = 1 ]] && tune_selinux
[[ "$task_all" = 1 || "$task_firewall" = 1 ]] && tune_firewall
[[ "$task_all" = 1 || "$task_mitigations" = 1 ]] && tune_mitigations

cleanup
