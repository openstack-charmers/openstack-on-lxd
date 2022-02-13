# Overview

An all-on-one machine OpenStack cloud can be useful for development of
OpenStack projects, OpenStack Charms, or for exercising and testing the same.

This repository provides resources and processes to support deployment of
OpenStack in LXD containers using Juju, a powerful application modelling tool.

Such a process is useful in developer scenarios where OpenStack can be deployed
to a single laptop or server, provided of course that enough resources are
available on the host machine.

These bundles, configurations, and processes can be customised to fit numerous
development or test scenarios.

## Requirements

Given that the entire cloud will be running on a single machine, that chosen
machine (henceforth known as the "host") is expected to be well resourced in
terms of CPU, memory, and storage backend. The resources available to the host
will dictate the deploy time of the cloud.

The below specifications are considered sufficient to deploy the cloud (does
not include workloads):

* 16 GiB memory
* 4 CPU cores (minimally i5 gen.)

It is important to have a fast disk subsystem. This can be achieved in various
ways:

* dedicated SSD block device
* traditional RAID array
* ZFS pool backed by multiple block devices
* btrfs array backed by multiple block devices

## Known limitations

Currently it is not possible to run Cinder with iSCSI/LVM based storage under
LXD. This limits block storage solutions to those that reside within userspace,
such as Ceph.

## Networking environment

This section describes the networking environment that will be used in this
example cloud.

The LXD network definition is summarised in this table:

|                     | value                  | comment                     |
| ------------------  | --------------------   | -------------------------   |
| LXD bridge name     | lxdbr0                 | Can also denote the network |
| LXD network address | 10.0.8.0/24            | --                          |
| LXD bridge address  | 10.0.8.1/24            | --                          |
| LXD DHCP range      | 10.0.8.2 -> 10.0.8.200 | Cloud node addresses        |

Other network parameters:

* The OpenStack floating IP range is `10.0.8.201 -> 10.0.8.254`.

* The OpenStack internal network address is `192.168.20.0/24` and its IP range is
  `192.168.20.10 -> 192.168.20.99`.

* IPv6 will be disabled on the container DHCP network (undercloud) as it can
  interfere with the host network (overcloud).

* Jumbo frames will be enabled for network connections into the containers.
  This will help avoid packet fragmentation type problems that can occur with
  overlay networks (overcloud and undercloud).

# Host

## Install the software

Install Juju and the OpenStack CLI clients on the host:

    sudo snap install juju --classic
    sudo snap install openstackclients --classic

Install ZFS if you will be using it to manage pools outside of LXD:

    sudo apt install zfsutils-linux

> **Note**: On Bionic, LXD is installed by default via apt packages, yet it is
  recommended to use the snap. **Providing you are not using the apt-based
  LXD**, install the snap and remove the packages:

    sudo snap install lxd
    sudo apt purge liblxc1 lxcfs lxd lxd-client

The snap also includes a tool to migrate containers over from the apt-based
deployment: `sudo lxd.migrate`. Once done it will offer to remove the old
software.

> **Note**: Ubuntu releases that are more recent than Bionic ship with LXD
  installed as a snap. There is nothing to do regarding LXD installation on
  these releases.

Download this repository:

    git clone https://github.com/openstack-charmers/openstack-on-lxd.git ~/openstack-on-lxd

## Set kernel options

OpenStack on LXD requires many thousands of file handles and the default kernel
thresholds should be increased accordingly. Not doing so may lead to issues
such as "too many open files". Kernel options should therefore be set as per
the [LXD production setup][lxd-production-setup] guide, specifically those related to the
`/etc/sysctl.conf` file. Note that swap usage will also be turned down to a
very low level.

> **Tip**: Instead of `/etc/sysctl.conf`, put sysctl parameters in an application-specific conf file in the `/etc/sysctl.d/` directory. This prevents conflicts with the system's package manager.

Change the kernel's behaviour in real-time like this:

    echo fs.inotify.max_queued_events=1048576 | sudo tee -a /etc/sysctl.d/50-openstack-on-lxd.conf
    echo fs.inotify.max_user_instances=1048576 | sudo tee -a /etc/sysctl.d/50-openstack-on-lxd.conf
    echo fs.inotify.max_user_watches=1048576 | sudo tee -a /etc/sysctl.d/50-openstack-on-lxd.conf
    echo vm.max_map_count=262144 | sudo tee -a /etc/sysctl.d/50-openstack-on-lxd.conf
    #echo vm.swappiness=1 | sudo tee -a /etc/sysctl.d/50-openstack-on-lxd.conf
    sudo sysctl -p /etc/sysctl.d/50-openstack-on-lxd.conf
    
# LXD

## Configure LXD

LXD needs to be initialised and configured:

    lxd init --auto

If the above fails, ensure your user is recognised as a member of the 'lxd'
group by issuing the `newgrp lxd` command.

> **Note**: An interactive user session will result if the ``--auto`` option is
  omitted.

Configure the LXD network as described earlier:

    lxc network set lxdbr0 ipv4.address 10.0.8.1/24
    lxc network set lxdbr0 ipv4.dhcp.ranges 10.0.8.2-10.0.8.200
    lxc network set lxdbr0 bridge.mtu 9000
    lxc network unset lxdbr0 ipv6.address
    lxc network unset lxdbr0 ipv6.nat

The third command enables Jumbo frames for the host's lxdbr0 bridge. We will
later configure Jumbo frames for containers by updating the LXD profile that
Juju will use when creating them.

Optionally set up a ZFS storage backend. For example, to do this for a pool
called 'lxd-zfs' that spans three unused block devices:

    sudo zpool create lxd-zfs sdb sdc sdd
    lxc storage create lxd-zfs zfs source=lxd-zfs

The LXD network configuration can be viewed with the command :command:`lxc
network show lxdbr0`.

## Verify LXD

It is recommended to verify that LXD itself is in good working order before
continuing. Do this by creating a test container ('focal-1'), issuing a remote
command on it, and then removing the container.

    lxc launch ubuntu-daily:focal focal-1
    lxc exec focal-1 whoami
    lxc delete -f focal-1

# Juju

## Create the Juju controller

Create a Juju controller based on the 'lxd' cloud type to manage the
deployment:

    juju bootstrap localhost lxd

This will also create the model 'default' and the corresponding LXD profile
'juju-default'. These will respectively be used to contain and configure the
cloud containers.

> **Tip**: An APT proxy, such as `squid-deb-proxy`, can be used to improve
  cloud installation performance. Define the proxy setting for the container
  'default' model with the command `juju model-config -m default
  apt-http-proxy=http://<host>:<port>`. See the [Juju proxy
  documentation][juju-proxy-documentation] for guidance.

## Update the LXD cloud container profile

Update the 'juju-default' profile with the help of file `lxd-profile.yaml`
provided by the repository downloaded earlier:

    cd ~/openstack-on-lxd
    cat lxd-profile.yaml | lxc profile edit juju-default

This will ensure that the containers will have the permissions they need for
a successful OpenStack deployment. It will also complete the enablement of
Jumbo frames for the containers.

You will also need to update this profile if you are using ZFS. In this
example deployment, the 'lxd-zfs' pool was previously set up:

    lxc profile device set juju-default root pool=lxd-zfs

The resulting profile can be viewed with the command `lxc profile show
juju-default`.

> **Note**: There is nothing special about the Juju 'default' model nor the LXD
   'juju-default' profile. For instance, you can create the model 'victoria'
   and then update the auto-created profile with `juju add-model victoria` and
   `cat lxd-profile.yaml | lxc profile edit juju-victoria`.

# OpenStack

## Select a bundle

The bundles are located in the `~/openstack-on-lxd` directory. Choose one
that is appropriate for the host's architecture.

For amd64, arm64, and ppc64el the bundle filenames are of this format:

`bundle-<ubuntu-series>-<openstack-release>.yaml`

For s390x the bundle filenames have the '-s390x' suffix appended:

`bundle-<ubuntu-series>-<openstack-release>-s390x.yaml`

There are also some OVN-specific bundles.

As an example, if the host is amd64 and we want to deploy OpenStack Victoria
running on Focal containers the following bundle will be selected:

`bundle-focal-victoria.yaml`

> **Important**: Starting with OpenStack Train, Ceph Mimic will be used in the
  bundles until a solution has been devised to address the dropping of
  directory backed OSD support in Ceph Nautilus. See bug [GH #72][gh-72].

## Deploy the cloud

Deploy the cloud now. Using our above example:

    cd ~/openstack-on-lxd
    juju deploy ./bundle-focal-victoria.yaml

You can watch deployment progress with the command `watch -n 5 -c juju status
--color`. This will take a while to complete.

It is normal for the ceilometer application to be blocked at the end of the
process. Overcome this with an action:

    juju run-action --wait ceilometer/0 ceilometer-upgrade

At this time it is recommended to verify that you can successfully query the
cloud's resources. Begin by sourcing the supplied init file:

    source openrcv3_project
    openstack catalog list
    openstack service list
    openstack network agent list
    openstack volume service list

## Configure OpenStack

### Import an image

You'll need to import a boot image into Glance in order to create instances.
The image architecture should match that of the host. Here we import a Focal
amd64 image and call it 'focal-amd64':

    curl http://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img | \
       openstack image create --public --container-format=bare --disk-format=qcow2 \
       focal-amd64

Images for other Ubuntu releases and architectures can be obtained in a similar
way, but for the ARM 64-bit (arm64) architecture you will need to configure the
image to boot in UEFI mode:

    curl http://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-arm64.img | \
       openstack image create --public --container-format=bare --disk-format=qcow2 \
       --property hw_firmware_type=uefi focal-arm64

> **Note**: If you are using a ZFS storage backend, the nova-compute charm's
  `force-raw-images` option is automatically disabled for OpenStack Pike and
  later. Be aware that using this setting in a production environment is
  discouraged as it may have an impact on performance.

### Configure the network

First, create the external network 'ext_net' and external subnet 'ext_subnet'
which map directly to the LXD bridge:

    openstack network create ext_net --external --share --default \
       --provider-network-type flat --provider-physical-network physnet1

    openstack subnet create ext_subnet --allocation-pool start=10.0.8.201,end=10.0.8.254 \
       --subnet-range 10.0.8.0/24 --no-dhcp --gateway 10.0.8.1 --network ext_net

Then create the internal network 'int_net' and internal subnet 'int_subnet' for
the instances to attach to:

    openstack network create int_net --internal

    openstack subnet create int_subnet \
       --allocation-pool start=192.168.20.10,end=192.168.20.99 \
       --subnet-range 192.168.20.0/24 \
       --gateway 192.168.20.1 --dns-nameserver 10.0.8.1 \
       --network int_net

Finally, connect the internal and external networks by means of router
'router1':

    openstack router create router1
    openstack router add subnet router1 int_subnet
    openstack router set router1 --external-gateway ext_net

### Create a flavor

Create at least one flavor to define a hardware profile for new instances. Here
we create one called 'm1.tiny':

    openstack flavor create --public --ram 512 --disk 5 --ephemeral 0 --vcpus 1 m1.tiny

### Import an SSH keypair

An SSH keypair needs to be imported into the cloud in order to access your
instances.

Generate one first if you do not yet have one. This command creates a
passphraseless keypair (remove the `-N` option to avoid that):

    ssh-keygen -q -N '' -f ~/.ssh/id_mykey

To import a keypair called 'mykey':

    openstack keypair create --public-key ~/.ssh/id_mykey.pub mykey

### Configure security groups

Allow ICMP (ping) and SSH traffic to flow to cloud instances by creating
corresponding rules for each default security group:

    for i in $(openstack security group list | awk '/default/{ print $2 }'); do
        openstack security group rule create $i --protocol icmp --remote-ip 0.0.0.0/0;
        openstack security group rule create $i --protocol tcp --remote-ip 0.0.0.0/0 --dst-port 22;
    done

You only need to perform this step once.

## Use OpenStack

### Create an instance

> **Note**: For OpenStack on LXD, if the host is PowerNV (ppc64el) you will
  need to disable `smt` manually before creating instances:

    juju ssh nova-compute/0 sudo ppc64_cpu --smt=off

Create a Bionic instance called 'bionic-1' using the 'bionic-amd64' image and
the 'm1.tiny' flavor:

    NET_ID=$(openstack network show int_net -f value -c id)
    openstack server create --image bionic-amd64 --flavor m1.tiny --key-name mykey \
       --network=$NET_ID bionic-1

### Attach a volume

This step is optional.

To create a 10GiB volume called 'vol-10g' in Cinder and attach it to instance
'bionic-1':

    openstack volume create --size=10 vol-10g
    openstack server add volume bionic-1 vol-10g
    openstack volume show vol-10g
 
The volume becomes immediately available to the instance. It will however need
to be formatted and mounted before usage.

### Assign a floating IP address

Request a floating IP address and assign it to instance 'bionic-1':

    FLOATING_IP=$(openstack floating ip create -f value -c floating_ip_address ext_net)
    openstack server add floating ip bionic-1 $FLOATING_IP

### Log in to an instance

Log in to an instance by connecting to its floating IP address:

    ssh -i ~/.ssh/id_mykey ubuntu@$FLOATING_IP

#### Troubleshooting

Here are a few troubleshooting tips if the SSH connection fails:

* Ensure that the instance has booted correctly with :command:`openstack
  console log show <instance-name>`.

* Ensure that the metadata service is running with :command:`openstack network
  agent list`.

## Access the dashboards

There are two web UIs available out of the box. These are the OpenStack
dashboard and the Juju dashboard.

### OpenStack dashboard

To access the OpenStack dashboard you'll need to determine its IP address and
the admin user's credentials. These two commands will provide them,
respectively:

    juju status openstack-dashboard | grep -A1 'Public address'
    juju run --unit keystone/leader 'leader-get admin_passwd'

Our example cloud yields an address of '10.0.8.69'.

Point your browser at the below URL and use the credentials (use your own IP
address):

    http://10.0.8.69/horizon

    domain:  admin_domain
    user:  admin
    password:  ??????????

If the host is remote you can use SSH local port forwarding to access it (use
your own IP address):

    ssh -N -L 10080:10.0.8.69:80 <remote-host>

The URL then becomes: http://localhost:10080/horizon

### Juju dashboard

To access the Juju dashboard you'll need to determine its URL and credentials.
Do so like this:

    juju dashboard

Our example cloud shows:

    Dashboard 0.1.7 for controller "lxd" is enabled at:
      https://10.0.8.18:17070/dashboard
    Your login credential is:
      username: admin
      password: 86f650892c26180a6bf2a116fb7df486

If the host is remote you can use SSH local port forwarding to access it (use
your own IP address):

    ssh -N -L 10070:10.0.8.18:17070 <remote-host>

The URL then becomes: https://localhost:10070/dashboard

<!-- LINKS -->

[lxd-production-setup]: https://github.com/lxc/lxd/blob/master/doc/production-setup.md
[juju-proxy-documentation]: https://juju.is/docs/offline-mode-strategies
[gh-72]: https://github.com/openstack-charmers/openstack-on-lxd/issues/72
