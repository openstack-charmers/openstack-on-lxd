# Fixes

## Load of nbd module under 14.04 in nova-compute upstart config

Fixed in git repo for Mitaka

Impact: nova-compute package/nova source package

## Install of headers package for OVS plugin

No longer required - drop in charm-helpers/tie to DKMS package requirement

Impact: neutron-openvswitch

## Ceph DIO under ZFS

DirectIO is not supported with a ZFS backend in Ceph; needs a flag to tell the OSD's not todo this.

[osd]
journal dio = false

Impact: ceph-osd, ceph charms.

# TODO

Update the LXD profile that juju creates to:

# Enable securty.privleged

This is currently required to support OVS in containers.

# Add /dev/kvm

Required for nova-compute

# Add extra interface

For neutron-gateway or DVR testing

# Set MTU's on interfaces to 9000

So we don't get packet frag in overlay networks.

