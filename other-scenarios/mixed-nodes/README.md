# HCI with Mixed Nodes

This example shows how to do an HCI deployment with Compute or OSD
nodes that are not homogeneous. Though the nodes are still physically
homogenus, they will be configured differently as follows: 

* r730xd_u29: Compute
* r730xd_u31: Osd10
* r730xd_u33: OsdComputeTwelve
* r730xd_u35: OsdComputeSix

In the above example, the number after each name, e.g. twelve or six,
represents the amount of OSDs per node. The first two will use the
default roles of Compute and CephStorage. The last two will be custom
roles named as above.

Only the OsdComputeTwelve node is using all of its physical resources as a
fully converged node. OsdComputeSix uses half of its actual HDD and SSD
capacity in order to show how to handle nodes that are smaller but
still have resources to contribute to the OpenStack cloud. The same
idea applies to Compute, which won't use any of its HDDs or SSDs,
aside from the RAID1 pair to support the operating system. Similarly,
Osd10 has capacity to offer compute services but will only offer Ceph
OSD services with less disks than it actually has.

## Assignment in Ironic

Each node is assigned to the roles above using the ironic-assign.sh
script as follows: 

```
./ironic-assign.sh r730xd_u29 compute
./ironic-assign.sh r730xd_u31 ceph-storage
./ironic-assign.sh r730xd_u33 osd-compute-twelve
./ironic-assign.sh r730xd_u35 osd-compute-six
```

After running the above, a variation of running `openstack baremetal
node show $uuid | grep properties` on each node looks like the
following:

```
 {u'cpu_arch': u'x86_64', u'root_device': {u'wwn': u'0x614187704e9ea700'}, u'cpus': u'56', u'capabilities': u'node:compute-0,boot_option:local', u'memory_mb': u'262144', u'local_gb': 277}                                  
 {u'cpu_arch': u'x86_64', u'root_device': {u'wwn': u'0x614187704e9ea500'}, u'cpus': u'56', u'capabilities': u'node:ceph-storage-0,boot_option:local', u'memory_mb': u'262144', u'local_gb': 277}                             
 {u'cpu_arch': u'x86_64', u'root_device': {u'wwn': u'0x614187704e9ea900'}, u'cpus': u'56', u'capabilities': u'node:osd-compute-twelve-0,boot_option:local', u'memory_mb': u'262144', u'local_gb': 277}                            
 {u'cpu_arch': u'x86_64', u'root_device': {u'wwn': u'0x614187704e9c7700'}, u'cpus': u'56', u'capabilities': u'node:osd-compute-six-0,boot_option:local', u'memory_mb': u'262144', u'local_gb': 277}
```

## Custom Templates for Mixed Deployment

The yaml files custom-templates-mixed contains the following files
which are variations custom-templates: 

* custom-roles-mixed.yaml
* layout-mixed.yaml
* network-mixed.yaml
* ceph-mixed.yaml
* compute-mixed.yaml

For example, custom-roles-mixed.yaml is a variation of
custom-roles.yaml which had an additional and identical copy of the 
OsdCompute role added to the bottom of the file. The first OsdCompute
then had a 12 appended to its name and its HostnameFormatDefault. The
second OsdCompute had the same change but 6 was used instead
of 12. Though these two custom roles are very similar, having two
definitions will be useful when assigning different lists of disks
when ceph-mixed.yaml is created and the same applies to the other
files listed above. 

## Compute Tuning

compute-mixed.yaml is a variation of compute.yaml. It has a different
reserved host memory or CPU allocation ratio per compute node. The
standard compute node, which does not run OSD services, uses the
recommended default for reserved host memory of 2048 MB (see RH BZ
1282644). It also uses the CPU allocation ratio deafult of 16. 

The compute nodes which run OSD services reserve differing amounts of
memory or provide differing CPU allocation ratios to the Nova
scheduler since they have have to reserve memory and CPU for the OSD
services that they run. However, they reserve differing amounts based
on the number of OSDs. For example, OsdComputeTwelve needs to reserve more
than OsdComputeSix because it has more OSDs which need those resources. 

```
  ComputeExtraConfig:
    nova::compute::reserved_host_memory: 2048
    nova::cpu_allocation_ratio: 16
  OsdComputeTwelveExtraConfig:
    nova::compute::reserved_host_memory: 181000
    nova::cpu_allocation_ratio: 8.2        
  OsdComputeSixExtraConfig:    
    nova::compute::reserved_host_memory: 19000
    nova::cpu_allocation_ratio: 8.9        
```

The 19000 and 8.9 MB above for OsdComputeSix was reached using the
nova_mem_cpu_calc.py as follows:

```
[stack@hci-director scripts]$ ./nova_mem_cpu_calc.py 256 56 6 2 0.1
Inputs:
- Total host RAM in GB: 256
- Total host cores: 56
- Ceph OSDs per host: 6
- Average guest memory size in GB: 2
- Average guest CPU utilization: 10%

Results:
- number of guests allowed based on memory = 95
- number of guest vCPUs allowed = 500
- nova.conf reserved_host_memory = 190000 MB
- nova.conf cpu_allocation_ratio = 8.928571

Compare "guest vCPUs allowed" to "guests allowed based on memory" for actual guest count
[stack@hci-director scripts]$ 
```

## Deployment

The mixed node HCI OpenStack cloud is deloyed with deploy-mixed.sh. 

## Observations

The deploy-mixed.sh script produces a working overcloud: 

```
[stack@hci-director ~]$ openstack server list
+-------------------------+-------------------------+--------+-----------------------+----------------+
| ID                      | Name                    | Status | Networks              | Image Name     |
+-------------------------+-------------------------+--------+-----------------------+----------------+
| a3ac512a-430a-4f1e-     | overcloud-compute-0     | ACTIVE | ctlplane=192.168.1.23 | overcloud-full |
| a5f0-da51cbb597a3       |                         |        |                       |                |
| 32397cfa-5bd4-4336-9fb9 | overcloud-cephstorage-0 | ACTIVE | ctlplane=192.168.1.25 | overcloud-full |
| -2af8cae721ee           |                         |        |                       |                |
| 205cd598-8ea8-4dbb-     | overcloud-osd-compute-  | ACTIVE | ctlplane=192.168.1.27 | overcloud-full |
| a5ca-5e19aaf5589c       | six-0                   |        |                       |                |
| 59d6ec10-2eb4-4d12-b8f2 | overcloud-controller-2  | ACTIVE | ctlplane=192.168.1.29 | overcloud-full |
| -badd5d063287           |                         |        |                       |                |
| 594277df-0336-4942-a909 | overcloud-controller-1  | ACTIVE | ctlplane=192.168.1.32 | overcloud-full |
| -dce338f68df8           |                         |        |                       |                |
| cf309150-aa82-4ae2      | overcloud-osd-compute-  | ACTIVE | ctlplane=192.168.1.26 | overcloud-full |
| -a6ba-7f503bcaee8e      | twelve-0                |        |                       |                |
| 80512072-d9bd-4d4d-     | overcloud-controller-0  | ACTIVE | ctlplane=192.168.1.21 | overcloud-full |
| addd-011124c536ed       |                         |        |                       |                |
+-------------------------+-------------------------+--------+-----------------------+----------------+
[stack@hci-director ~]$ 
```

The compute node tunings per role are reflected in the _nova.conf_
files of each compute node. If Ansible is installed, only for the
purposes of inspecting the nodes with ad hoc scripts, then these
Nova compute settings may be observed as follows: 

```
[stack@hci-director ~]$ ansible computes -b -m shell -a "hostname; egrep 'cpu_allocation_ratio|reserved_host_memory' /etc/nova/nova.conf"
192.168.1.23 | SUCCESS | rc=0 >>
overcloud-compute-0.localdomain
reserved_host_memory_mb=2048

192.168.1.27 | SUCCESS | rc=0 >>
overcloud-osd-compute-six-0.localdomain
reserved_host_memory_mb=19000
cpu_allocation_ratio=8.9

192.168.1.26 | SUCCESS | rc=0 >>
overcloud-osd-compute-twelve-0.localdomain
reserved_host_memory_mb=181000
cpu_allocation_ratio=8.2

[stack@hci-director ~]$
```
 
