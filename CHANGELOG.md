
## 1.8.1 (v1.8.1)

* cf4/server.cf4
  - add support for placement groups and EC2 instance tenancy
  - optionally specific a server's private ip
  - add the ability to conditionally specify the private ip address
  - simplify the conditional CNAME feature
  - create iam roles for bastion and nat, reduce app role privs
  - add an ExtraHelper parameter
  - improve "make validate" to test templates and userdata scripts
  - add some cidr definitions
  - fixes and improvements to bootstrap/mount-disks.sh
  - DEVOPS-33 DEVOPS-53
