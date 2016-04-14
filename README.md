# Fixes

# LXD Profile - see lxd-profile.yaml

Update the LXD profile that juju creates to:

cat lxd-profile.yaml | lxc profile edit juju-default

## Enable securty.privleged

This is currently required to support libvirt in containers.

## Add /dev/kvm

Required for nova-compute

## Add extra interface

For neutron-gateway or DVR testing

## Set MTU's on interfaces to 9000

So we don't get packet frag in overlay networks.

## DTRT

```
./setup.sh
```
