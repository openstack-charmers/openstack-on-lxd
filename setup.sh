#!/bin/bash

set -ex

mkdir -p trusty

[ -d trusty/ceph ] || bzr co --lightweight lp:~james-page/charms/trusty/ceph/lp1535315 trusty/ceph
[ -d trusty/ceph-osd ] || bzr co --lightweight lp:~james-page/charms/trusty/ceph-osd/lp1535315 trusty/ceph-osd

cat lxd-profile.yaml | lxc profile edit juju-openstack-on-lxd
