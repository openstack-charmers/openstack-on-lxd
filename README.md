# Overview

This repository provides resources and processes to support deployment of OpenStack in LXD containers using Juju, a powerful application modeling tool.

Such a process is useful in developer scenarios where OpenStack can be deployed to a single laptop or server, provided of course that enough resources are available. It can also be deployed in a virtual machine if a host is configured to allow nested virtualization and the required CPU features are enabled for a guest's CPU model (the [DevStack with KVM-based Nested Virtualization guide](http://docs.openstack.org/developer/devstack/guides/devstack-with-nested-kvm.html) contains useful information on how to do it).

These bundles, configurations and processes can be customized to fit numerous development or production scenarios.

For full details of use please refer the the [OpenStack on LXD](http://docs.openstack.org/developer/charm-guide/openstack-on-lxd.html) section of the [OpenStack Charm Guide](http://docs.openstack.org/developer/charm-guide).
