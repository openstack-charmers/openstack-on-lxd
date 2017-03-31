#!/bin/bash -ex
# Sync neutron config tools from openstack-charm-testing

oct_tmp="$(mktemp -d)"
bzr export $oct_tmp https://code.launchpad.net/~ost-maintainers/openstack-charm-testing/trunk

tools="neutron-ext-net neutron-tenant-net"
for tool in $tools; do
    cp -fvp $oct_tmp/bin/$tool $tool
done
rm -rf $oct_tmp
