# Deploy OpenStack on LXD on your Laptop

## Overview

This repository provides tools to support deployment of OpenStack in LXD containers using Juju, the service modelling tool for Ubuntu.

## Requirements

The tools in this repository require the use of Juju 2.0, which provides full support for the LXD local provider.

```
sudo apt-get install juju lxd zfsutils-linux squid-deb-proxy
```

These tools are provided as part of the Ubuntu 16.04 LTS release.

You'll need a well specified machine to try this on with at least 8G of RAM and a SSD; for reference the author uses Lenovo x240 with an Intel i5 processor, 16G RAM and a 500G Samsung SSD (split into two - one partition for the OS and one partition for a ZFS pool).

## LXD configuration

In order to allow the OpenStack Cloud to function, you'll need to reconfigure the default LXD bridge to support IPv4 networking; is also recommended that you use a fast storage backend such as ZFS on a SSD based block device.  Use the lxd provided configuration tool to help do this:

```
sudo lxd init
```

Ensure that you leave a range of IP addresses free to use for floating IP's for OpenStack instances; For reference the author used:

    Network and IP: 10.0.8.1/24
    DHCP range: 10.0.8.2 -> 10.0.8.200

Also update the default profile to use Jumbo frames for all network connections into containers:

```
lxc profile device set default eth0 mtu 9000
```

This will ensure you avoid any packet fragmentation type problems with overlay networks.

## Test your configuration

Test out your configuration prior to launching an entire cloud:

```
lxc launch ubuntu-daily:xenial
```

This should result in a running container you can exec into:

```
lxc exec <container-name> bash
```

## LXD profile for Juju

Juju creates a couple of profiles for the models that it creates by default; these are named juju-default and juju-admin.

Create and update the juju-default profile prior to bootstrapping your environment:

```
lxc profile create juju-default 2>/dev/null || echo "juju-default profile already exists"
cat lxd-profile.yaml | lxc profile edit juju-default
```

This will ensure that containers created by LXD for Juju have the correct permissions to run your OpenStack cloud.

## Bootstrap a Juju controller

Prior to deploying the OpenStack on LXD bundle, you'll need to bootstrap a controller to manage your Juju models:

```
juju bootstrap --config config.yaml localhost lxd
```

Review the contents of the config.yaml prior to running this command and edit as appropriate; this configures some defaults for containers created in the model including setting up things like a APT proxy to improve performance of network operations.

## Deploy the bundle

Next, deploy the OpenStack cloud using the provided bundle:

```
juju deploy bundle.yaml
```

You can watch deployment progress using the 'juju status' command.  This may take some time depending on the speed of your system; CPU, disk and network speed will all effect deployment time.

## Check access

Once deployment has completed (units should report a ready state in the status output), check that you can access the deployed cloud OK:

```
source novarc
keystone catalog
nova service-list
neutron agent-list
cinder service-list
```

This commands should all succeed and you should get a feel as to how the various OpenStack components are deployed in each container.

## Upload an image

## Configure some networks

## Boot an instance and access it

## Allocate a block device and present it to the instancea

## Access the dashboard
