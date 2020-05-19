# Cloud MPI

This repository contains a list of tunings to get better performance for HPC applications. Effect of each of these tuning depends from application to application. In some cases, a particular tuning may have a negative effect on the performance. Hence the user is advised to experiment with these to identify the right set of tuning for their workload.  The directory contains both bash and ansible scripts.


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
1. networklatency - Enable busy polling and low network latency profile
1. limits - Change the system ulimits
1. nosmt - Disable simultaneous multi threading
1. nofirewalld - Disable firewalld
1. noselinux - Disable SE Linux
1. nomitigation - Disable CPU vulnerabilities mitigations

## Bash Scripts

Use `mpi-tuning.sh` to apply tunings on indvidual VMs.

```shell
sudo mpi-tuning.sh [options]
```

The following options are available
```shell
  Usage:
    Verify tuning steps: mpi-tuning.sh [options] --dryrun
    Apply tunings: mpi-tuning.sh [options]

  Options:
    --tcpmem           Increase memory for TCP
    --networklatency   Enable busy polling and low network latency profile
    --limits           Change the system ulimits
    --nosmt            Disable simultaneous multi threading (reboot requried)
    --nofirewalld      Disable firewalld
    --noselinux        Disable SE Linux (reboot required)
    --nomitigation     Disable CPU vulnerabilities mitigations (reboot required)
    --reboot           Reboot system after tunings if required
    --dryrun           Do not execute commands
    --verbose          Print verbose messages
    --help             Show help message
```

## MPI Collectives tuning configurations

Directory mpitune-configs/intelmpi-2018 contains output configurations from Intel MPI collective tunings performed on c2-standard-60 with placement groups.

To use these tuning files, copy these files to
```shell
$MPIHOME/compilers_and_libraries_2018/linux/mpi/etc64
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

