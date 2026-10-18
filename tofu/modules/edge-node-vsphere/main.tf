# Edge node on a customer's vSphere cluster, cloned from an Ubuntu 24.04 cloud image template.
terraform {
  required_providers {
    vsphere = {
      source  = "vmware/vsphere"
      version = ">= 2.10, < 3.0"
    }
  }
}

variable "datacenter" { type = string }
variable "cluster" { type = string }
variable "datastore" { type = string }
variable "network" { type = string }
variable "folder" {
  type    = string
  default = "ops-edge"
}
variable "template" {
  type        = string
  description = "Ubuntu 24.04 cloud image template with cloud-init and VMware guestinfo datasource."
}
variable "userdata" { type = any }

data "vsphere_datacenter" "dc" { name = var.datacenter }
data "vsphere_compute_cluster" "c" {
  name          = var.cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_datastore" "ds" {
  name          = var.datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_network" "net" {
  name          = var.network
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_virtual_machine" "template" {
  name          = var.template
  datacenter_id = data.vsphere_datacenter.dc.id
}

resource "vsphere_virtual_machine" "edge" {
  name             = var.userdata.edge_node
  folder           = var.folder
  resource_pool_id = data.vsphere_compute_cluster.c.resource_pool_id
  datastore_id     = data.vsphere_datastore.ds.id
  num_cpus         = 2
  memory           = 4096
  guest_id         = data.vsphere_virtual_machine.template.guest_id
  firmware         = data.vsphere_virtual_machine.template.firmware

  network_interface {
    network_id = data.vsphere_network.net.id
  }

  disk {
    label            = "disk0"
    size             = 40
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
  }

  extra_config = {
    "guestinfo.userdata"          = base64encode(var.userdata.user_data)
    "guestinfo.userdata.encoding" = "base64"
    "disk.EnableUUID"             = "TRUE"
  }

  lifecycle {
    # The wrapped secret_id is single use; re-rendering it must not rebuild a running node.
    ignore_changes = [extra_config]
  }
}

output "name" {
  value = vsphere_virtual_machine.edge.name
}
