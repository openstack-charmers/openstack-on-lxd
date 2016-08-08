# Deploy OpenStack on LXD

## Overview

This repository provides resources and processes to support deployment of OpenStack in LXD containers using Juju, a powerful application modeling tool.

Such a process is useful in developer scenarios where OpenStack can be deployed to a single laptop or server, provided of course that enough resources are available.

These bundles, configurations and processes can be customized to fit numerous development or production scenarios.

## Deployment

### Requirements

The tools in this repository require the use of Juju 2.0, which provides full support for the LXD local provider.

```
sudo apt-get install juju lxd zfsutils-linux squid-deb-proxy \
    python-novaclient python-keystoneclient python-glanceclient \
    python-neutronclient python-openstackclient
```

These tools are provided as part of the Ubuntu 16.04 LTS release.

You'll need a well specified machine with at least 8G of RAM and a SSD; for reference the author uses Lenovo x240 with an Intel i5 processor, 16G RAM and a 500G Samsung SSD (split into two - one partition for the OS and one partition for a ZFS pool).

For s390x, this has been validated on an LPAR with 12 CPUs, 40GB RAM, 2 ~40GB disks (one disk for the OS and one disk for the ZFS pool).

### LXD configuration

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

### Test your configuration

Test out your configuration prior to launching an entire cloud:

```
lxc launch ubuntu-daily:xenial
```

This should result in a running container you can exec into and back out of:

```
lxc exec <container-name> bash
exit
```

### LXD profile for Juju

Juju creates a couple of profiles for the models that it creates by default; these are named juju-default and juju-admin.

Create and update the juju-default profile prior to bootstrapping your environment:

```
lxc profile create juju-default 2>/dev/null || echo "juju-default profile already exists"
cat lxd-profile.yaml | lxc profile edit juju-default
```

This will ensure that containers created by LXD for Juju have the correct permissions to run your OpenStack cloud.

### Bootstrap a Juju controller

Prior to deploying the OpenStack on LXD bundle, you'll need to bootstrap a controller to manage your Juju models:

```
juju bootstrap --config config.yaml localhost lxd
```

Review the contents of the config.yaml prior to running this command and edit as appropriate; this configures some defaults for containers created in the model including setting up things like a APT proxy to improve performance of network operations.

### Configure a PowerNV (ppc64el) Host

When deployed directly to metal, the nova-compute charm sets smt=off, as is necessary for libvirt usage.  However, when nova-compute is in a container, the containment prevents ppc64_cpu from modifying the host's smt value.  It is necessary to pre-configure the host smt setting for nova-compute (libvirt + qemu) in ppc64el scenarios.

```
sudo ppc64_cpu --smt=off
```

### Deploy the bundle

Next, deploy the OpenStack cloud using the provided bundle:

For amd64:
```
juju deploy bundle.yaml
```

For s390x:
```
juju deploy bundle-s390x.yaml
```

For ppc64el (PowerNV):
```
juju deploy bundle-ppc64el.yaml
```

You can watch deployment progress using the 'juju status' command.  This may take some time depending on the speed of your system; CPU, disk and network speed will all effect deployment time.

## Using the Cloud

### Check access

Once deployment has completed (units should report a ready state in the status output), check that you can access the deployed cloud OK:

```
source novarc
openstack catalog list
nova service-list
neutron agent-list
cinder service-list
```

This commands should all succeed and you should get a feel as to how the various OpenStack components are deployed in each container.

### Upload an image

Before we can boot an instance, we need an image to boot in Glance:

For amd64:

```
curl http://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-disk1.img | \
    openstack image create --public --container-format=bare --disk-format=qcow2 xenial
```

For s390x:

```
curl http://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-s390x-disk1.img | \
    openstack image create --public --container-format=bare --disk-format=qcow2 xenial
```

### Configure some networks

First, create the 'external' network which actually maps directly to the LXD bridge:

```
./neutron-ext-net -g 10.0.8.1 -c 10.0.8.0/24 \
    -f 10.0.8.201:10.0.8.254 ext_net
```

and then create an internal overlay network for the instances to actually attach to:

```
./neutron-tenant-net -t admin -r provider-router \
    -N 10.0.8.1 internal 192.168.20.0/24
```

### Create a key-pair

Upload your local public key into the cloud so you can access instances:

```
nova keypair-add --pub-key ~/.ssh/id_rsa.pub mykey
```

### Boot an instance

You can now boot an instance on your cloud:

```
nova boot --image xenial --flavor m1.small --key-name mykey \
   --nic net-id=$(neutron net-list | grep internal | awk '{ print $2 }') \
   openstack-on-lxd-ftw
```

### Attaching a volume

First, create a volume in cinder:

```
cinder create --name testvolume 10
```

then attach it to the instance we just booted in nova:

```
nova volume-attach openstack-on-lxd-ftw $(cinder list | grep testvolume | awk '{ print $2 }') /dev/vdc
```

The attached volume will be accessible once you login to the instance (see below).  It will need to be formatted and mounted!

### Accessing your instance


In order to access the instance you just booted on the cloud, you'll need to assign a floating IP address to the instance:

```
nova floating-ip-create
nova add-floating-ip <uuid-of-instance> <new-floating-ip>
```

and then allow access via SSH (and ping) - you only need todo this once:

```
neutron security-group-rule-create --protocol icmp \
    --direction ingress $(nova secgroup-list | grep default | awk '{ print $2 }')
neutron security-group-rule-create --protocol tcp \
    --port-range-min 22 --port-range-max 22 \
    --direction ingress $(nova secgroup-list | grep default | awk '{ print $2 }')
```

After running these commands you should be able to access the instance:

```
ssh ubuntu@<new-floating-ip>
```
