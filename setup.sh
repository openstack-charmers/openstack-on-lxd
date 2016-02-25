#!/bin/bash

set -ex

cat lxd-profile.yaml | lxc profile edit juju-openstack-on-lxd
