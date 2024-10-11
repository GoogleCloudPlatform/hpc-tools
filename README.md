# Cloud MPI

This repository contains scripts for tunings presented in [Best practices for running tightly coupled HPC applications on Compute Engine](https://cloud.google.com/solutions/best-practices-for-using-mpi-on-compute-engine). Tightly coupled High Performance Computing (HPC) workloads often use MPI to communicate between processes and instances. Proper tuning of the underlying systems and network infrastructure is essential for optimal MPI performance. If you run MPI-based code in Google Cloud, use these practices to get the best possible performance. The benefits of each of these tuning depends from application to application. In some cases, a particular tuning may have a negative effect on the performance. Hence the user is advised to experiment with these to identify the right set of tuning for their workload.  This repository contains both bash and ansible scripts.

##  Ansible Scripts

Use the following command to Install ansible
``` shell
sudo yum install -y ansible
```

Each of the tunings are tagged with names, so that users can select the required set of tunings for their application.  Use the following command to run a playbook.

``` shell
ansible-playbook mpi-tuning-ansible.yaml -i hostfile --tags [tcpmem,networklatency,limits,nosmt,nofirewalld,noselinux,nomitigation] -f num_parallel_scripts
```

The following tags can be used

1. tcpmem - Increase memory for TCP
1. networklatency - Enable busy polling and low network latency tuned profile
1. limits - Change the system ulimits
1. nosmt - Disable simultaneous multi threading
1. nofirewalld - Disable firewalld
1. noselinux - Disable SE Linux
1. nomitigation - Disable CPU vulnerabilities mitigations

## Bash Scripts

Use `mpi-tuning.sh` to apply tunings on individual VMs.

```shell
sudo mpi-tuning.sh [options]
```

The following options are available

```shell
  Usage:
    Verify tuning steps: mpi-tuning.sh [options] --dryrun
    Apply tunings: mpi-tuning.sh [options]

  Options:
    --hpcprofile       Install and apply google-hpc-compute tuned profile
                       Also applies: --tcpmem, --limits
    --hpcthroughput    Install and apply google-hpc-compute-throughput profile
                       Also applies: --tcpmem, --limits
    --tcpmem           Increase memory for TCP
    --limits           Change the system ulimits
    --nosmt            Disable simultaneous multi threading
    --nofirewalld      Disable firewalld
    --noselinux        Disable SE Linux (reboot required)
    --nomitigation     Disable CPU vulnerabilities mitigations (reboot required)
    --reboot           Reboot system after tunings if required
    --dryrun           Do not execute commands
    --verbose          Print verbose messages
    --help             Show help message
```


Use `google_install_mpi` to install IntelMPI 2018 environment on individual VMs. Note that this script only supports CentOS-7.

```shell
sudo google_install_mpi [options]
```

The following options are available

```shell
  Usage:
    Verify installation steps: google_install_mpi  [options] --dryrun
    Apply IntelMPI environment installation: google_install_mpi  [options]

  Options:
    -h | --help          Display help message
    --dryrun             Do not execute commands
    --prefix             Configure the prefix directory for installations
                         Default location is set to /opt/intel
    --intel_checker      Install Intel(R) Cluster Checker
    --intel_compliance   Configure environment in compliance with Intel(R) HPC
                         platform specification. Include Intel(R) HPC Platform
                         Specification meta-packages, Intel(R) Performance
                         Libraries and Intel(R) Distribution for Python
    --intel_psxe_runtime Install Intel(R) Parallel Studio XE Runtime 2018
    --intel_comp_meta    Install Intel(R) HPC Platform Specification
                         meta-packages
    --intel_mpi          Install Intel(R) MPI 2018 (Recommended version
                         for running MPI jobs on Google Cloud)
    --intel_python       Install latest Intel(R) Distribution for Python
```

Use `google_install_intelmpi` to install IntelMPI 2021 environment on individual VMs.

```shell
sudo google_install_intelmpi [options]
```

The following options are available

```shell
  Usage:
    Verify installation steps: google_install_intelmpi [options] --dryrun
    Apply installation: google_install_intelmpi [options]

  Options:
    -h | --help          Display help message
    --dryrun             Do not execute commands
    --install_dir <path> Configure the prefix directory for installations
                         Default location is set to /opt/intel
    --impi_2021          Install Intel(R) MPI 2021.13 (Recommended version
                         for running MPI jobs on Google Cloud)
```



## MPI Collectives tuning configurations

Directory mpitune-configs/intelmpi-2018 contains output configurations from Intel MPI 2018 collective tunings performed on c2-standard-60 with placement groups.

To use these tuning files, install the Intel MPI library 2018, source the `mpivars.[c]sh` script to set up the proper environment, then run the installation script:

```shell
./google_install_mpitune
```

Tuning configuration needs to be available for the combination of the number of VMs and the number of processes per VM. If it is not available, you can use mpitune utility. For example, to tune for 22 VMs and 30 processes per VM, run the following:

```shell
mpitune -hf hostfile -fl ‘shm:tcp’ -pr 30:30 -hr 22:22
```

This will generate a configuration file in the Intel MPI directory which can be used later to run applications. The user must have write access to this directory or this command must be run as root.

To make use of the tuning configuration for an application add -tune option to mpirun command line.

```shell
mpirun -tune -hostfile hostfile -genv I_MPI_FABRICS ‘shm:tcp’ -np 660 -ppn 30 ./app
```

## Building `google-hpc-compute` package

`google-hpc-compute` is a package that applies the bash tuning script and installs the MPI collectives tuning configurations. This package is pre-installed on the HPC VM image.

Currently only CentOS 7 and Rocky Linux 8 RPM packages are supported.

To build this package, install `rpm-build` and run the `build_rpm.sh` script.

```shell
./[centos_7|rocky_linux_8]/packaging/build_rpm.sh
```

The package will be built in `/tmp/rpmpackage`, to install, use `yum` or `rpm` command:

```shell
sudo yum install /tmp/rpmpackage/RPMS/x86_64/google-hpc-compute-20200818.00-g1.el7.x86_64.rpm
```

This will apply all tunings (except for `--nomitigation`) and install the content of this project to the following locations:

- Tuning script: `/usr/bin/google_mpi_tuning`
- Mpitune installation script: `/usr/bin/google_install_mpitune`
- Collective tuning configurations: `/usr/share/google-hpc-compute`

Using the tuning script (renamed as `google_mpi_tuning`) to apply the `--nomitigation` tuning (and reboot) manually:

```shell
sudo google_mpi_tuning --nomitigation --reboot
```

Users can opt-out the tunings by removing this package.
