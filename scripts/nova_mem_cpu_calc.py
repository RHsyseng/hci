#!/usr/bin/env python
# Filename:                nova_mem_cpu_calc.py
# Supported Langauge(s):   Python 2.7.x, Python 3.7.x
# Time-stamp:              <2020-02-20 13:52:01 fultonj>
# -------------------------------------------------------
# This program was originally written by Ben England
# -------------------------------------------------------
# Calculates cpu_allocation_ratio and reserved_host_memory
# for nova.conf based on on the following inputs: 
#
# input command line parameters:
# 1 - total host RAM in GB
# 2 - total host cores 
# 3 - Ceph OSDs per server
# 4 - average guest size in GB
# 5 - average guest CPU utilization (0.0 to 1.0)
#
# It assumes that we want to allow 3 GB per OSD 
# (based on prior Ceph Hammer testing)
# and that we want to allow an extra 1/2 GB per Nova (KVM guest)
# based on test observations that KVM guests' virtual memory footprint
# was actually significantly bigger than the declared guest memory size
# This is more of a factor for small guests than for large guests.
# -------------------------------------------------------
import sys
from sys import argv

NOTOK = 1  # process exit status signifying failure
MB_per_GB = 1000

GB_per_OSD = 3
GB_overhead_per_guest = 0.5  # based on measurement in test environment
cores_per_OSD = 1.0  # may be a little low in I/O intensive workloads

def usage(msg):
  print(msg)
  print(
    ("Usage: %s Total-host-RAM-GB Total-host-cores OSDs-per-server " + 
     "Avg-guest-size-GB Avg-guest-CPU-util") % sys.argv[0])
  sys.exit(NOTOK)

if len(argv) < 6: usage("Too few command line params")
try:
  mem = int(argv[1])
  cores = int(argv[2])
  osds = int(argv[3])
  average_guest_size = int(argv[4])
  average_guest_util = float(argv[5])
except ValueError:
  usage("Non-integer input parameter")

average_guest_util_percent = 100 * average_guest_util

# print inputs
print("Inputs:")
print("- Total host RAM in GB: %d" % mem)
print("- Total host cores: %d" % cores)
print("- Ceph OSDs per host: %d" % osds)
print("- Average guest memory size in GB: %d" % average_guest_size)
print("- Average guest CPU utilization: %.0f%%" % average_guest_util_percent)

# calculate operating parameters based on memory constraints only
left_over_mem = mem - (GB_per_OSD * osds)
number_of_guests = int(left_over_mem / 
                       (average_guest_size + GB_overhead_per_guest))
nova_reserved_mem_MB = MB_per_GB * (
                        (GB_per_OSD * osds) + 
                        (number_of_guests * GB_overhead_per_guest))
nonceph_cores = cores - (cores_per_OSD * osds)
guest_vCPUs = nonceph_cores / average_guest_util
cpu_allocation_ratio = guest_vCPUs / cores

# display outputs including how to tune Nova reserved mem

print("\nResults:")
print("- number of guests allowed based on memory = %d" % number_of_guests)
print("- number of guest vCPUs allowed = %d" % int(guest_vCPUs))
print("- nova.conf reserved_host_memory = %d MB" % nova_reserved_mem_MB)
print("- nova.conf cpu_allocation_ratio = %f" % cpu_allocation_ratio)

if nova_reserved_mem_MB > (MB_per_GB * mem * 0.8):
    print("ERROR: you do not have enough memory to run hyperconverged!")
    sys.exit(NOTOK)

if cpu_allocation_ratio < 0.5:
    print("WARNING: you may not have enough CPU to run hyperconverged!")

if cpu_allocation_ratio > 16.0:
    print(
        "WARNING: do not increase VCPU overcommit ratio " + 
        "beyond OSP8 default of 16:1")
    sys.exit(NOTOK)

print("\nCompare \"guest vCPUs allowed\" to \"guests allowed based on memory\" for actual guest count")
