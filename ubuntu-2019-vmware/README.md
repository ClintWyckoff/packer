# Building an Ubuntu 20.04 VMware Template with HashiCorp Packer

This tutorial walks you through completely automating the process of building a VMware Template of **Ubuntu 20.04**. This tutorial leverages Packer and is ideal for a completely hands-off approach of creating repeatable templates to deploy off of. For example, the image is able to be further customized and deployed with Terraform. This tutorial is specific to Ubuntu 20.04 and the process for earlier versions of Ubuntu will be different.

### Introduction

There are a few files which are utilized in the template creation which you will need to familiarize yourself with:

* *credentials.json* ==> This file contains all VMware environment variable definitions.
* *ubuntu.json* ==> This is the 'Builder' and 'Provisioner' file which contains the bits required to build the VM and issue the appropriate boot commands { `boot_command` } into the grub loader.
* *./http* ==> This directory will contain 2 files - user-data and meta-data. The entire folder and contents will be copied to a webserver.
* *./http/user-data* ==> This file contains the cloud-init cloud-config contents which were automatically set during the manual installer process.
* .*/http/meta-data* ==> blank file, required presence for cloud-init
* *./script/* ==> Any .sh scripts which need to be executed as part of the post-installation process via provisioner.

#### **Recommendations**

* When any system is installed using the server installer, an autoinstall file for repeating the install is created at `/var/log/installer/autoinstall-user-data`. It is recommended to manually go through the installer process, obtain the autoinstall-user-data file, rename the file to `user-data` and place in the http directory.
* Host http on a separate web server in the environment. Issues were encountered when using the Packer web server during the build process.
* This tutorial builds the VMware Template. To take this tutorial to the next step, users may utilize Terraform to fully provision and deploy the virtual machine(s) into the environment. When deploying VMs using Terraform you will use the [VMware Terraform provider](https://registry.terraform.io/modules/Terraform-VMWare-Modules/vm/vsphere/latest). The provider offers the ability to specify Linux or Windows VM customizations which include setting the OS hostname and adding the server to the domain.

### Getting the VMware Environment Ready for Packer

[Packer](https://www.packer.io/) automates the creation of any type of machine image. It embraces modern configuration management by encouraging you to use automated scripts to install and configure the software within your Packer-made images. You may download Packer [here](https://www.packer.io/downloads). This tutorial was built utilizing Packer version v1.6.6.

**Assumptions:**

* vCenter Server
* VMware ESXi Host(s)
* VMware Datastore(s)
* [Download Ubuntu 20.04 ISO](https://releases.ubuntu.com/). You may use `iso_url` in place of `iso_path` and download / upload during packer build however this adds significant time to the packer build process.

### Customize the VMware Environment Variables

In order to connect to the VMware environment and build our VM Template we must populate our the environment details. Best practice is to utilize credentials file(s). IN this tutorial we will customize `credentials.json` file which will contain all necessary and relevant VMware environment details and stores them as variables in which are referenced within `ubuntu.json`.

Below is an example of what a sample `credentials.json` may look like.

In order to connect to the VMware environment and build our VM Template we must populate our the environment details. Best practice is to utilize credentials file(s). IN this tutorial we will customize `credentials.json` file which will contain all necessary and relevant VMware environment details and stores them as variables in which are referenced within `ubuntu.json`.

Below is an example of what a sample `credentials.json` may look like.

```json
{
    "vsphere-server": "vcenter.server.name",
    "vsphere-user": "administrator@vsphere.local",
    "vsphere-password": "$up3r$3cr3t",
    
    "vsphere-datacenter": "Datacenter-Name",
    "vsphere-cluster": "Cluster-Name",
    "vsphere-network": "vmnetwork",
    "vsphere-datastore": "datstore-name",
    "vsphere-folder": "Folder-Name",
      
    "vm-name": "Ubuntu2004-Template-Base-Fix",
    "vm-cpu-num": "2",
    "vm-mem-size": "4096",
    
    "os-disk-size": "40960",
    "disk-thin-provision": "true",
    
    "ssh_username": "ubuntu",
    "ssh_password": "ubuntu",
    
    "os_iso_path": "[files-lab-iso] path/toiso.iso"
}
```

### Prepare the ubuntu.json Build file

The json document begins with a Builders section and this tutorial is utilizing the [Packer Builder for VMware vSphere](https://www.packer.io/docs/builders/vmware/vsphere-iso) - specifically the `vsphere-iso` builder. There are many documented examples provided by Hashicorp on their [official Packer GitHub Repository](https://github.com/hashicorp/packer/tree/master/builder/vsphere/examples/).

The top section of the builders file defines the vSphere environment and references the values which were defined in `credentials.json`

``````      json
{  
	"builders": [
    {
      "type": "vsphere-iso",
      "vcenter_server": "{{user `vsphere-server`}}",
      "username": "{{user `vsphere-user`}}",
      "password": "{{user `vsphere-password`}}",
      "insecure_connection": "true",
      "datacenter": "{{user `vsphere-datacenter`}}",
      "cluster": "{{user `vsphere-cluster`}}",
      "datastore": "{{user `vsphere-datastore`}}",
      "folder": "{{user `vsphere-folder`}}",
      "convert_to_template": "true",
      "vm_name": "{{user `vm-name`}}",
      "guest_os_type": "ubuntu64Guest",
      "CPUs": "{{user `vm-cpu-num`}}",
      "RAM": "{{user `vm-mem-size`}}",
      "RAM_reserve_all": true,
      "firmware": "bios",
  
      "storage": [
        {
          "disk_size": "{{user `os-disk-size`}}",
          "disk_thin_provisioned": "{{user `disk-thin-provision`}}"
        }
      ],
      "disk_controller_type": "lsilogic-sas",
          
      "network_adapters": [
        {
          "network": "{{user `vsphere-network`}}",
          "network_card": "vmxnet3"
        }
      ],
``````

Next, in the builder file you must define the boot commands which will be directly passed to the grub loader when the VM boots to the ISO image.

```json
"boot_wait": "5s",
      "boot_command": [
        " <wait><enter><wait>",
        "<f6><esc>",
        "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
        "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
        "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
        "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
        "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
        "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
      "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
      "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
      "<bs><bs><bs>",
      "/casper/vmlinuz ",
      "initrd=/casper/initrd --- ",
      "autoinstall ",
      "ds=nocloud-net;seedfrom=http://homes.nebulon.com/cdub/http/",
      "<enter>"
    ],
      "shutdown_command": "echo '{{ user `ssh_password` }}'| sudo -S shutdown -P now",

        "ssh_username": "nebulon",
        "ssh_password": "Nebulon123!",
        "ssh_timeout": "20m",
        "ssh_port": 22,
        "http_directory": "http",
```

This section defines the `iso_path`. Alternatively you can use `iso_urls` and directly point to the ISO image from Ubuntu.

```json
"iso_paths": ["{{user `os_iso_path`}}"]
      }
    ],
```

Here we will utilize the Open-SSH server on the VM and open an SSH connection which will utilize the [Shell Provisioner](https://www.packer.io/docs/provisioners/shell) to execute commands and scripts inside the VM. You can execute shell scripts also, for example to install `VMware tools` or execute `apt-get update`.

```json
"provisioners": [
    {
      "execute_command": "echo '{{ user `ssh_password` }}' | {{.Vars}} sudo -E -S bash '{{.Path}}'",
      "scripts": [
        "script/update.sh",
        "script/vmware.sh"
      ],
      "type": "shell"
    }
  ]
}
```

### Host the Cloud-Config Files on a WebServer

It is recommended to stand-up a simple [Apache](https://ubuntu.com/tutorials/install-and-configure-apache#1-overview) or [Nginx](https://ubuntu.com/tutorials/install-and-configure-nginx#1-overview) web server. In our testing we noticed inconsistencies when using the default Packer webserver and this method provided the best results. You will move the entire ./http folder which contains with the `user-data` and `meta-data` files.

The `meta-data` file is empty but required to be present for Cloud-Init. The second file, `user-data` contains all of the Ubuntu installation items and functions as the main answer file for the OS installation - including keyboard layout, locale, ethernet setup, SSH Server installation and disk layout. The recommended approach is to install manually then obtain the completed `autoinstall` file from `/var/log/installer/autoinstall-user-data`

### Update the Ubuntu.json to seedfrom the local WebServer

We need to update the `ubuntu.json` file and ensure the `seedfrom` points to the local webserver - `seedfrom=http://webserver.local/http",` ==> Line 52. Be sure that the full /http is provided in the seedfrom url.

### Build the Ubuntu 20.04 Template with Packer Build

To build the Ubuntu 20.04 template we will run the packer build command using the `-var--file` switch which will point at our `credentials.json` file. 

The full command will look like: `packer build -var-file .\credentials.json .\ubuntu.json`

To follow along and watch the deployment in real-time you may open the VMware Remote Console to view the progress. The end result will be a fully provisioned Ubuntu 20.04 VMware Template.

The console output will look like this:

```shell
vsphere-iso: output will be in this color.`

`==> vsphere-iso: Creating VM...`
`==> vsphere-iso: Customizing hardware...`
`==> vsphere-iso: Mounting ISO images...`
`==> vsphere-iso: Adding configuration parameters...`
`==> vsphere-iso: Starting HTTP server on port 8696`
`==> vsphere-iso: Set boot order temporary...`
`==> vsphere-iso: Power on VM...`
`==> vsphere-iso: Waiting 5s for boot...`
`==> vsphere-iso: HTTP server is working at http://10.100.251.29:8696/`
`==> vsphere-iso: Typing boot command...`
`==> vsphere-iso: Waiting for IP...`
`==> vsphere-iso: IP address: 10.100.27.5`
`==> vsphere-iso: Using ssh communicator to connect: 10.100.27.5`
`==> vsphere-iso: Waiting for SSH to become available...`
`==> vsphere-iso: Connected to SSH!`
`==> vsphere-iso: Provisioning with shell script: script/update.sh`
    `vsphere-iso: ==> Disabling the release upgrader`
    `vsphere-iso: ==> Checking version of Ubuntu`
    `vsphere-iso: ==> Disabling periodic apt upgrades`
    `vsphere-iso: ==> Updating list of repositories`
    `vsphere-iso: Hit:1 http://us.archive.ubuntu.com/ubuntu focal InRelease`
    `vsphere-iso: Get:2 http://us.archive.ubuntu.com/ubuntu focal-updates InRelease [114 kB]`
    `vsphere-iso: Get:3 http://us.archive.ubuntu.com/ubuntu focal-backports InRelease [101 kB]`
    `vsphere-iso: Get:4 http://us.archive.ubuntu.com/ubuntu focal-security InRelease [109 kB]`
    `vsphere-iso: Get:5 http://us.archive.ubuntu.com/ubuntu focal/restricted amd64 Packages [22.0 kB]`
    `vsphere-iso: Get:6 http://us.archive.ubuntu.com/ubuntu focal/restricted Translation-en [6212 B]`
    `vsphere-iso: Get:7 http://us.archive.ubuntu.com/ubuntu focal/restricted amd64 c-n-f Metadata [392 B]`
    `vsphere-iso: Get:8 http://us.archive.ubuntu.com/ubuntu focal/universe amd64 Packages [8628 kB]`
    `vsphere-iso: Get:9 http://us.archive.ubuntu.com/ubuntu focal/universe Translation-en [5124 kB]`
    `vsphere-iso: Get:10 http://us.archive.ubuntu.com/ubuntu focal/universe amd64 c-n-f Metadata [265 kB]`
    `vsphere-iso: Get:11 http://us.archive.ubuntu.com/ubuntu focal/multiverse amd64 Packages [144 kB]`
    `vsphere-iso: Get:12 http://us.archive.ubuntu.com/ubuntu focal/multiverse Translation-en [104 kB]`
    `vsphere-iso: Get:13 http://us.archive.ubuntu.com/ubuntu focal/multiverse amd64 c-n-f Metadata [9136 B]`
    `vsphere-iso: Get:14 http://us.archive.ubuntu.com/ubuntu focal-updates/main amd64 Packages [807 kB]`
    `vsphere-iso: Get:15 http://us.archive.ubuntu.com/ubuntu focal-updates/main Translation-en [195 kB]`
    `vsphere-iso: Get:16 http://us.archive.ubuntu.com/ubuntu focal-updates/main amd64 c-n-f Metadata [11.8 kB]`
    `vsphere-iso: Get:17 http://us.archive.ubuntu.com/ubuntu focal-updates/restricted amd64 Packages [146 kB]`
    `vsphere-iso: Get:18 http://us.archive.ubuntu.com/ubuntu focal-updates/restricted Translation-en [21.9 kB]`
    `vsphere-iso: Get:19 http://us.archive.ubuntu.com/ubuntu focal-updates/restricted amd64 c-n-f Metadata [436 B]`
    `vsphere-iso: Get:20 http://us.archive.ubuntu.com/ubuntu focal-updates/universe amd64 Packages [740 kB]`
    `vsphere-iso: Get:21 http://us.archive.ubuntu.com/ubuntu focal-updates/universe Translation-en [153 kB]`
    `vsphere-iso: Get:22 http://us.archive.ubuntu.com/ubuntu focal-updates/universe amd64 c-n-f Metadata [15.6 kB]`
    `vsphere-iso: Get:23 http://us.archive.ubuntu.com/ubuntu focal-updates/multiverse amd64 Packages [16.9 kB]`
    `vsphere-iso: Get:24 http://us.archive.ubuntu.com/ubuntu focal-updates/multiverse Translation-en [5076 B]`
    `vsphere-iso: Get:25 http://us.archive.ubuntu.com/ubuntu focal-updates/multiverse amd64 c-n-f Metadata [536 B]`
    `vsphere-iso: Get:26 http://us.archive.ubuntu.com/ubuntu focal-backports/main amd64 c-n-f Metadata [112 B]`
    `vsphere-iso: Get:27 http://us.archive.ubuntu.com/ubuntu focal-backports/restricted amd64 c-n-f Metadata [116 B]`
    `vsphere-iso: Get:28 http://us.archive.ubuntu.com/ubuntu focal-backports/universe amd64 Packages [4032 B]`
    `vsphere-iso: Get:29 http://us.archive.ubuntu.com/ubuntu focal-backports/universe Translation-en [1448 B]`
    `vsphere-iso: Get:30 http://us.archive.ubuntu.com/ubuntu focal-backports/universe amd64 c-n-f Metadata [224 B]`
    `vsphere-iso: Get:31 http://us.archive.ubuntu.com/ubuntu focal-backports/multiverse amd64 c-n-f Metadata [116 B]`
    `vsphere-iso: Get:32 http://us.archive.ubuntu.com/ubuntu focal-security/main amd64 Packages [489 kB]`
    `vsphere-iso: Get:33 http://us.archive.ubuntu.com/ubuntu focal-security/main Translation-en [107 kB]`
    `vsphere-iso: Get:34 http://us.archive.ubuntu.com/ubuntu focal-security/main amd64 c-n-f Metadata [6204 B]`
    `vsphere-iso: Get:35 http://us.archive.ubuntu.com/ubuntu focal-security/restricted amd64 Packages [123 kB]`
    `vsphere-iso: Get:36 http://us.archive.ubuntu.com/ubuntu focal-security/restricted Translation-en [18.0 kB]`
    `vsphere-iso: Get:37 http://us.archive.ubuntu.com/ubuntu focal-security/restricted amd64 c-n-f Metadata [392 B]`
    `vsphere-iso: Get:38 http://us.archive.ubuntu.com/ubuntu focal-security/universe amd64 Packages [536 kB]`
    `vsphere-iso: Get:39 http://us.archive.ubuntu.com/ubuntu focal-security/universe Translation-en [76.1 kB]`
    `vsphere-iso: Get:40 http://us.archive.ubuntu.com/ubuntu focal-security/universe amd64 c-n-f Metadata [9804 B]`
    `vsphere-iso: Get:41 http://us.archive.ubuntu.com/ubuntu focal-security/multiverse amd64 Packages [10.4 kB]`
    `vsphere-iso: Get:42 http://us.archive.ubuntu.com/ubuntu focal-security/multiverse Translation-en [2876 B]`
    `vsphere-iso: Get:43 http://us.archive.ubuntu.com/ubuntu focal-security/multiverse amd64 c-n-f Metadata [284 B]`
    `vsphere-iso: Fetched 18.1 MB in 5s (3723 kB/s)`
    `vsphere-iso: Reading package lists...`
`==> vsphere-iso: [sudo] password for nebulon:`
`==> vsphere-iso: Provisioning with shell script: script/vmware.sh`
`==> vsphere-iso: [sudo] password for nebulon:`
`==> vsphere-iso: Executing shutdown command...`
`==> vsphere-iso: Deleting Floppy drives...`
`==> vsphere-iso: Eject CD-ROM drives...`
`==> vsphere-iso: Convert VM into template...`
`==> vsphere-iso: Clear boot order...`
`Build 'vsphere-iso' finished after 4 minutes 28 seconds.`

`==> Wait completed after 4 minutes 28 seconds`

`==> Builds finished. The artifacts of successful builds are:`
`--> vsphere-iso: Ubuntu2004-Template-Base-Fix
```