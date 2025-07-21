#!/bin/bash
# Copyright 2021 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script disables automatic updates.

set -x -e -o pipefail

# Disable the OSConfig Agent.
#   The 'tasks' feature allows the Patch service to run on the VM.
#   Unfortunately, the OSConfig Agent runs `yum check-update` whether or not
#   the 'tasks' feature is enabled.
#   More info: https://cloud.google.com/compute/docs/os-patch-management
systemctl disable google-osconfig-agent.service
systemctl stop google-osconfig-agent.service

systemctl disable dnf-automatic.timer
systemctl stop dnf-automatic.timer
systemctl disable dnf-automatic.service
systemctl stop dnf-automatic.service

systemctl disable dnf-makecache.timer
systemctl stop dnf-makecache.timer
systemctl disable dnf-makecache.service
systemctl stop dnf-makecache.service

systemctl disable dnf-automatic-download.timer
systemctl stop dnf-automatic-download.timer
systemctl disable dnf-automatic-download.service
systemctl stop dnf-automatic-download.service

systemctl disable dnf-automatic-install.timer
systemctl stop dnf-automatic-install.timer
systemctl disable dnf-automatic-install.service
systemctl stop dnf-automatic-install.service

rm -f /var/lib/systemd/timers/stamp-dnf-automatic.timer
