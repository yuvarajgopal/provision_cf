
cft-core    1.8.1   (TAG = v1.8.1)
==================================

This is a library of some core CloudFormation templates that can be
used as the basis for an AWS project.

With these templates and the provision_aws and cftgen tools (packaged
separately), it is possible to quickly spin up a new AWS environment
using the standard model of dmz subnets, private subnets, and public
subnets across two availability zones.  The templates were designed to
be modular and reusable.  Some templates are specific, like the chef
server and chef squid proxy, but even those can be used as reference
templates to craft other custom template.

These templates were successfully used in a small proof-of-concept
project, and were the basis of an overhaul of the ContentHub
CloudFormation.

This is only preliminary documentation.  I will continue to work on
better documentation and usage instructions, including more Confluence
pages.



New features in this release (1.8.1)
------------------------------------

  * add support for placement groups and EC2 instance tenancy
  * add the ability to conditionally specify the private ip address
  * simplify the conditional CNAME feature
  * add an ExtraHelper parameter
  * improve "make validate" to test templates and userdata scripts
  * DEVOPS-53


New features in release (1.6.5)
------------------------------------

  * Some fixes to the Makefiles


New features in release (1.6.4)
-------------------------------
  * this README
  * fixed some template syntax errors in network-routing and chef-squid-proxy

New features in release (1.6.3)
-------------------------------
  * Fixed Outputs description in network-route53 template

New features in release (1.6.2)
-------------------------------
  * fixed an internet gateway name bug bug in the network-vpc template
  * added a new "ManageMyCredentials" group to the iam-groups template

New features in release (1.6.1)
-------------------------------
  * improved bootstrap/install-chef-client-script.sh
  * updated version for pip and awscli in bootstrap/sncr-aws-versions.sh
  * restricted instance role/profile in iam-roles.cf[4t]

New features in release (1.5.1)
-------------------------------

  * up to 12 volumes may now be specified in the server.cft
  * all templates now have Outputs for some important resources
  * new instance sizes have been incorporated in some templates
  * some updates to the Makefiles
  * requires cftgen v2.3.1 or newer

New features in release (1.4.5)
-------------------------------

  * add c3 and c4 instance types to bandwidth map
  * requires cftgen 2.2.6 or newer

New features in release (1.4.4)
-------------------------------
  * update nat-server.cft

New features in release (1.4.3)
-------------------------------

  * The NAT server now has the RootDiskDevice parameter.

New features in release (1.4.2)
-------------------------------

  * reliability updates to bootstrap/mount-disks.sh to allow limited
    retries while the EBS attachments are completed.

New features in release (1.4.1)
-------------------------------

  * Added RootDiskDevice and OptDiskDevice parameters to server.cft
  * Simplified the mount-disks.sh bootstrap helper to treat /opt like
    any other volume.
  * This release was necessary to test CentOS-6.6 AMIs that were
    built from packer using a base image from CentOS.org in the AWS
    marketplace.
  * Added example stanzas for the centos66 server amis in testing/opshub.conf
  * Minor enhancements to the provision status email
  * VPC's will now have a name tag like project-env, e.g. opshub-DEV.
  * This version requires cftgen v2.2.5 or newer
  * The swap device is now /dev/xvdb in server.cft

New features in Release 1.4.0
-----------------------------

  * Support for Enterprise Chef
    - Additional CFT Params (notably ChefOrg)
    - Enhanced bootstrap/install-chef-client.sh helper script
    - CHEF_ORG added to userdata scripts
  * added simple versioing to cf4/cft files
  * new network-route53.cf[4t] to create the dns zone
  * new network-routing.cf[4t] to create route tables
    - includes support for routing to a vpc-peer

New Features in Release (1.3.0)
-------------------------------

  * Enhanced EBS Volume Support for the generic server template.  See
    below for more information.

  * The OPS_ALERTS_TOPIC variable is now exposed from the userdata
    scripts so it can be used to publish alert messages.  For example,
    the signal-wait-condition.sh bootstrap helper now publishes a
    message when server provisioning is complete.

  * Changes and Enhancements to some bootstrap scripts to support the
    new features


### Enhanced Volume Support

  It is now possible to format and mount up to nine additional EBS
  volumes in the generic server.cft template.  The volumes can be of
  any currently supported EBS type: standard (old magnetic), gp2 (new
  SSD), and io1 (provisioned IOPS.).

  The following excerpt from the sample.conf shows an example of how
  each volume type must be defined.

```bash
...
PRIVATE_SERVER_CF_PARAM_Volume1=10,standard,/dev/xvdx,/extra/standard
PRIVATE_SERVER_CF_PARAM_Volume5=10,io1,/dev/xvdy,/extra/piops,100
PRIVATE_SERVER_CF_PARAM_Volume9=10,gp2,/dev/xvdz,/extra/gp2
...
```

  These parameters would cause the private server to have three
  additional volumes mounted, in addition to its root volume and
  already optional /opt volume.

  The template parameters have names, Volume1, Volume2, ..., Volume9.
  Each parameter must specify in this order the size (in GB) of the
  volume, the type, the device attachment, the mount point, and the
  provisioned iops if it is an io1 type volume.

  Notes:

   1. The actual mounting is done via the bootstrap/mount-disks.sh
      helper script. That script first detaches any volumes (usually
      ephemeral) that were automatically attached by cloudconfig, then
      it (conditionally) mounts the /opt as it has always done, then
      it searches for additional volumes attached to the interface via
      AWS tags that were created by the server template.

   2. The script does some simple sanity checking, but it is easy to
      outsmart it.  For example there is nothing to stop you from
      mounting two volumes in the same directory.

   3. If the mount point is not valid, e.g., "None", the volume should
      not be formatted or mounted by the helper.  that could be
      useful if the volume needs to be processed later, possibly as
      part of a chef recipe.

   4. When deleting a stack that has additional volumes, the first
      delete stack operation will fail because the volumes are
      attached to the instance.  The second delete stack operation
      will remove the volumes.


New Features in Release 1.2.1
-----------------------------

   * some cleanup of the templates, including comments

   * the creation of an independent nat security group that is not
     part of the base network security groups. Previously, Thee nat just
     used the (wide open) internal vpc security group.  Now, NAT
     traffic can be locked down independent of the rest of the
     intra-vpc traffic.  The delivered nat security group currently
     only allows http (80), https (443), smtp (25), and smtps(587).
     Remember, the primary use of the NAT is to allow instances inside
     private (non-internet facing subnets) access to amazon services
     like S3, yum repos, etc.


   * use of the BootPriority and Purpose parameters

     - BootPriority could be used to define a sets of instances that
         must be started/stopped in a certain order.

     - Purpose can (currently) be either 'infrastructure' or
        'component' to indicate if an instance is component of the
        application or part of the infrastructure that supports the
        application



Directory/File Layout
---------------------

```
.
├── README.md             this file, in Markdown
├── bootstrap
│   └── *.sh              helper script for public s3
├── cf4
│   ├── *.cf4             cf4 source for cftgen
│   ├── *.map             CF Mappings
│   ├── userdata-*.sh     userdata for CF
│   └── userdata-*.sh.jl  "join list" of userdata lines
├── *.cft                 generated JSON CF templates
├── current.release       holds this release version
├── docs
│   └── release-*.ann     release announcements
├── Makefile              sample Makefile
├── sample.conf           sample configuration for provision_aws
├── scripts
│   ├── *.sh             development tools
│   └── *.shlib          shared shell library functions
├── testing
    ├── opshub.conf      OpsHub project (sample) configuration
    └── opshub.mk        OpsHub project (sample) Makefile

```

Usage
-----
   clone this git repository

   Checkout the appropriate tag, currently "v1.8.1". Otherwise, you
   will likely get a development version that is "in progress" and
   probably un-tested.

   For now, either copy everything into a new project directory with
   the same directory layout, or remove the .git/ directory, rename
   the directory itself, and initialize it as its own git repository
   for the cloud formation part of your project.

   !! DO NOT COMMIT/PUSH CHANGES BACK TO cft-core.git  !!

   The exact sequence to get the released version should be something
   like the following, where TAG is the desired release tag

```bash
      cd <some-directory>
      git clone ssh://stash.synchronoss.net:7999/devops/cft-core.git
      cd cft-core
      git checkout TAG
```

Dependencies
------------

  * provison_aws
    -  launch the stacks

  * cftgen (version 2.3.1 or newer)
    - converts cf4 -> cft via m4 macro libraries
    - needed if you want to modify the existing cf4 sources or create
    new templates via the m4 macros

  * chef or Enterprise Chef
    - a working chef server and/or proxy
    - chef server will need the various roles and cookbooks for the
      chef server, chef proxy server, dmz nat, and dmz bastion entities

  * s3 public bucket
    - chef-client (and chef-server) rpms
    - helper scripts form the bootstrap/ directory

  * s3 private bucket
    - the chef validator key
    - the seed chef repo for a local chef server, if used


---

Stephen Corbesero, SCV

stephen.corbesero@synchronoss.com
