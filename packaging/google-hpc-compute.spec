# Copyright 2020 Google Inc. All Rights Reserved.
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

# Don't build debuginfo packages.
%define debug_package %{nil}

# For EL7, if building on CentOS, override dist to be el7.
%if 0%{?rhel} == 7
  %define dist .el7
%endif

Name: google-hpc-compute
Epoch:   1
Version: %{_version}
Release: g1%{?dist}
Summary: Google HPC Image tuning.
License: ASL 2.0
Url: https://github.com/GoogleCloudPlatform/hpc-tools
Source0: %{name}_%{version}.orig.tar.gz
Requires: tuned
Requires: google-compute-engine
Requires: google-guest-agent

BuildArch: %{_arch}
%if ! 0%{?el6}
BuildRequires: systemd
%endif

%description
This package contains scripts, configuration, and pre-tuned configuration files
for tuning MPI applications running on Google Compute Engine cloud environment.

%prep
%autosetup

%install
install -d %{buildroot}%{_bindir}
install -d %{buildroot}%{_unitdir}
install -p -m 0755 mpi-tuning.sh %{buildroot}%{_bindir}/google_mpi_tuning
install -p -m 0755 google_install_mpitune %{buildroot}%{_bindir}/google_install_mpitune
install -p -m 0755 google_hpc_multiqueue %{buildroot}%{_bindir}/google_hpc_multiqueue
install -p -m 0644 google-hpc-multiqueue.service %{buildroot}%{_unitdir}/google-hpc-multiqueue.service
install -p -m 0755 google_hpc_firstrun %{buildroot}%{_bindir}/google_hpc_firstrun
install -p -m 0644 google-hpc-firstrun.service %{buildroot}%{_unitdir}/google-hpc-firstrun.service
install -p -m 0755 google_install_mpi %{buildroot}%{_bindir}/google_install_mpi
install -d %{buildroot}%{_datadir}/google-hpc-compute
cp -ar mpitune-configs %{buildroot}%{_datadir}/google-hpc-compute
cp -ar vmroot %{buildroot}%{_datadir}/google-hpc-compute/mpi-tuning
install -d %{buildroot}%{_sysconfdir}/security/limits.d
install -p -m 0644 vmroot/etc/security/limits.d/98-google-hpc-image.conf %{buildroot}%{_sysconfdir}/security/limits.d/98-google-hpc-image.conf
install -d %{buildroot}/lib/tuned/google-hpc-compute
install -p -m 0644 vmroot/usr/lib/tuned/google-hpc-compute/tuned.conf %{buildroot}/lib/tuned/google-hpc-compute/tuned.conf

%files
%defattr(-,root,root,-)
%{_bindir}/google_mpi_tuning
%{_bindir}/google_install_mpitune
%{_bindir}/google_hpc_multiqueue
%{_unitdir}/google-hpc-multiqueue.service
%{_bindir}/google_hpc_firstrun
%{_unitdir}/google-hpc-firstrun.service
%{_bindir}/google_install_mpi
%{_datadir}/google-hpc-compute/*
%{_sysconfdir}/security/limits.d/98-google-hpc-image.conf
/lib/tuned/google-hpc-compute/tuned.conf

%pre
if [ $1 -gt 1 ] ; then
  # fallback to virtual-guest if necessary
  current_profile=$(tuned-adm active | cut -d' ' -f4)
  if [[ $current_profile == "google-hpc-compute" ]]; then
    tuned-adm profile virtual-guest
  fi
fi

%post
# Enable tuned profile
tuned-adm profile google-hpc-compute
# Enable multiqueue script
systemctl enable google-hpc-multiqueue.service >/dev/null 2>&1 || :
# Enable hpc image firstrun script
systemctl enable google-hpc-firstrun.service >/dev/null 2>&1 || :

if [ -d /run/systemd/system ]; then
  systemctl daemon-reload >/dev/null 2>&1 || :
  systemctl start google-hpc-multiqueue.service >/dev/null 2>&1 || :
fi

#fi

%preun
if [ $1 -eq 0 ]; then
  # Package removal, not upgrade

  # Fallback to generic google_set_multiqueue
  systemctl --no-reload disable google-hpc-multiqueue.service >/dev/null 2>&1 || :
  systemctl --no-reload disable google-hpc-firstrun.service >/dev/null 2>&1 || :
  if [ $(command -v "google_set_multiqueue") ]; then
    google_set_multiqueue >/dev/null 2>&1 || :
  fi

  # Fallback to virtual-guest if necessary
  current_profile=$(tuned-adm active | cut -d' ' -f4)
  if [[ $current_profile == "google-hpc-compute" ]]; then
    tuned-adm profile virtual-guest
  fi
fi

%postun
#if [ $1 -eq 0 ]; then
  # Package removal, not upgrade
#fi
