#!/bin/bash

set -ex

echo "Pre-loading kernel modules"
modprobe openvswitch
modprobe nbd
modprobe ip6_tables
modprobe ip_tables
