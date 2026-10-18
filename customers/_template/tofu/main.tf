# Edge nodes for this customer, one per site. Pick the platform module that matches the site.
# State lives in our backend, one state per customer; nothing secret is stored in this file.
terraform {
  backend "s3" {} # configured per customer at init: -backend-config=../../../tofu/backend.hcl
}

variable "role_id" { type = string }
variable "wrapped_secret_id" {
  type      = string
  sensitive = true
}

module "userdata_hq" {
  source              = "../../../tofu/modules/edge-node-userdata"
  tenant_id           = "TENANT_ID"
  site_id             = "hq"
  bao_addr            = "https://bao.ops.example:8200"
  oo_endpoint         = "https://observe.ops.example"
  ssh_authorized_keys = ["ssh-ed25519 AAAA... ops-team"]
  role_id             = var.role_id
  wrapped_secret_id   = var.wrapped_secret_id
}

module "edge_hq" {
  source     = "../../../tofu/modules/edge-node-vsphere"
  datacenter = "DC1"
  cluster    = "Cluster01"
  datastore  = "DS-PROD-01"
  network    = "VLAN20-Servers"
  template   = "tpl-ubuntu-2404-cloud"
  userdata   = module.userdata_hq
}

provider "vsphere" {
  vsphere_server = "vcenter.TENANT_ID.example"
  # VSPHERE_USER and VSPHERE_PASSWORD come from the environment (OpenBao), never from here.
}
