# Building a Windows Server 2019 VMware Template with HashiCorp Packer

This tutorial walks you through completely automating the process of building a VMware Template of **Windows Server 2019**. This tutorial leverages Packer and is ideal for a completely hands-off approach of creating repeatable templates to deploy off of. For example, the image is able to be further customized and deployed with Terraform. This tutorial will deploy a Windows Server 2019 Standard Edition Server with an Evaluation License key.

### Introduction

There are a few files which are utilized in the template creation which you will need to familiarize yourself with:

* *credentials.json* ==> This file contains all VMware environment variable definitions.
* *windows2019.json* ==> This file is the Windows Server builder file which contains references to the `credentials.json` file.
* *autounattend.xml* ==> This is the Windows Server installation answer file which contains information like locale, language, keyboard layout, OSImage Version - { WINDOWS SERVER 2019 SERVERSTANDARD }, Time Zone, along with Synchronous Commands. These are used during the post-installation process to install additional software packages or execute scripts within the Guest OS.
* .*/scripts/** ==> This directory contains any post-installation scripts which you would like to have executed when the server auto-login executes.

#### Recommendations

* This tutorial builds the VMware Template. To take this tutorial to the next step, users may utilize Terraform to fully provision and deploy the virtual machine(s) into the environment. When deploying VMs using Terraform you will use the [VMware Terraform provider](https://registry.terraform.io/modules/Terraform-VMWare-Modules/vm/vsphere/latest). The provider offers the ability to specify Linux or Windows VM customizations which include setting the OS hostname and adding the server to the domain.

### Getting the VMware Environment Ready for Packer

[Packer](https://www.packer.io/) automates the creation of any type of machine image. It embraces modern configuration management by encouraging you to use automated scripts to install and configure the software within your Packer-made images. You may download Packer [here](https://www.packer.io/downloads). This tutorial was built utilizing Packer version v1.6.6.

**Assumptions:**

- vCenter Server
- VMware ESXi Host(s)
- VMware Datastore(s)
- Download the [Windows Server 2019 ISO](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server) from the Windows Evaluation Center. You may use `iso_url` in place of `iso_path` and download / upload during packer build however this adds significant time to the packer build process.

### Customize the VMware Environment Variables

In order to connect to the VMware environment and build our VM Template we must populate our the environment details. Best practice is to utilize credentials file(s). IN this tutorial we will customize `credentials.json` file which will contain all necessary and relevant VMware environment details and stores them as variables in which are referenced within `ubuntu.json`.

Below is an example of what a sample `credentials.json` may look like.

```json
{
    "vsphere-server": "vcenter.server.name",
    "vsphere-user": "administrator@vsphere.local",
    "vsphere-password": "$up3r$3cr3t",
    "vm-name": "Ubuntu2004-Template-Base-Fix",
	"vm-cpu-num": "2",
	"vm-mem-size": "4096",
    "vsphere-datacenter": "Datacenter-Name",
	"vsphere-cluster": "Cluster-Name",
	"vsphere-network": "vmnetwork",
	"vsphere-datastore": "datstore-name",
	"vsphere-folder": "Folder-Name",
	"vm-name": "Win2019STD-Template-Base-Choco",
	"vm-cpu-num": "2",
	"vm-mem-size": "4096",
    "os-disk-size": "40960",
	"disk-thin-provision": "true",
    
    "winadmin-password": "Win-RM-Password!",
    
    "os_iso_path": "[files-lab-iso] path/toiso.iso"
}
```

### Prepare the windows2019.json Build File

This json document begins with a Builders section, known as a {block}. This tutorial is utilizing the [Packer Builder for VMware vSphere](https://www.packer.io/docs/builders/vmware/vsphere-iso) - specifically the `vsphere-iso` builder. As reference, there are many documented examples provided by Hashicorp on their [official Packer GitHub Repository](https://github.com/hashicorp/packer/tree/master/builder/vsphere/examples/).

The top section of the json document defines the vSphere environment and references the values which were defined within the `credentials.json` file.

```json
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
  
        "communicator": "winrm",
        "winrm_username": "Administrator",
        "winrm_password": "{{user `winadmin-password`}}",
        "winrm_timeout": "1h30m",
  
        "convert_to_template": "true",

        "vm_name": "{{user `vm-name`}}",
        "guest_os_type": "windows9Server64Guest",
  
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
        
        "shutdown_command": "shutdown /s /t 5",
```

Next, in the builder file we will define the define the OS ISO image along with the VMware Tools ISO.

```json
"iso_paths": [
          "{{user `os_iso_path`}}",
          "[] /vmimages/tools-isoimages/windows.iso"
        ],
```

Lastly, in the builder file you must provide the unattended installation items. For example, when the VM is built using Packer a virtual floppy (A:\) is attached and contains autounattend.xml file for the OS installation as well as the post-installation scripts.

```json
"floppy_files": [
            "autounattend.xml",
            "scripts/disable-network-discovery.cmd",
            "scripts/disable-server-manager.ps1",
            "scripts/enable-rdp.cmd",
            "scripts/enable-winrm.ps1",
            "scripts/install-vm-tools.cmd",
            "scripts/choco-install.ps1",
            "scripts/set-temp.ps1"
        ]
    }
  ],
  
  "provisioners": [
    {
      "type": "windows-shell",
      "inline": ["ipconfig /all"]
    }
  ]  
}
```

### Build the Windows Server 2019 Standard Template with Packer Build

To build the Windows Server 2019 template we will run the packer build command using the `--var-file` switch and point at the `credentials.json` file.

The full command will look like: `packer build -var-file .\credentials.json .\windows2019.json`

To follow along and watch the deployment in real-time you may open the VMware Remote Console to view the progress. The end result will be a fully provisioned Windows Server 2019 VMware Template.