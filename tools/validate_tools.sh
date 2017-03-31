#!/bin/bash -ex

oct_tmp="$(mktemp -d)"
bzr export $oct_tmp https://code.launchpad.net/~ost-maintainers/openstack-charm-testing/trunk
echo rm -rfv $oct_tmp

tools="neutron-ext-net neutron-tenant-net"
for tool in $tools; do
    if ! diff -Naur $oct_tmp/bin/$tool $tool; then
       echo "FAIL: $tool has too much diff against o-c-t"
      exit 1
    fi
done
