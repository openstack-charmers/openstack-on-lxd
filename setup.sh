#!/bin/bash

set -e

lxc profile create juju-default 2>/dev/null || echo "juju-default profile already exists"

echo "Updating juju-default profile for OpenStack on LXD"
cat lxd-profile.yaml | lxc profile edit juju-default
