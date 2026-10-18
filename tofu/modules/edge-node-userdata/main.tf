# Renders the cloud-init user data for a per-site edge node from the files in edge/.
# Every platform module (vSphere, Azure, AWS) uses this, so all edge nodes are identical.

variable "tenant_id" { type = string }
variable "site_id" { type = string }
variable "bao_addr" { type = string }
variable "oo_endpoint" { type = string }
variable "zabbix_server" {
  type    = string
  default = ""
}
variable "ssh_authorized_keys" { type = list(string) }
variable "role_id" {
  type        = string
  description = "OpenBao AppRole role_id for this site's edge node (not secret on its own)."
}
variable "wrapped_secret_id" {
  type        = string
  sensitive   = true
  description = "Response-wrapped secret_id with a short TTL; useless once unwrapped or expired."
}

locals {
  edge_node = "edge-${var.tenant_id}-${var.site_id}"
  edge_dir  = "${path.module}/../../../edge"
}

output "edge_node" {
  value = local.edge_node
}

output "user_data" {
  sensitive = true
  value = templatefile("${local.edge_dir}/cloud-init/user-data.yaml.tftpl", {
    tenant_id           = var.tenant_id
    site_id             = var.site_id
    edge_node           = local.edge_node
    bao_addr            = var.bao_addr
    oo_endpoint         = var.oo_endpoint
    oo_org              = var.tenant_id
    zabbix_server       = var.zabbix_server
    secrets_path        = "secret/customers/${var.tenant_id}"
    ssh_authorized_keys = var.ssh_authorized_keys
    role_id             = var.role_id
    wrapped_secret_id   = var.wrapped_secret_id
    compose_file        = file("${local.edge_dir}/compose/docker-compose.yml")
    versions_file       = file("${local.edge_dir}/compose/versions.env")
    openbao_agent_file  = file("${local.edge_dir}/compose/openbao-agent.hcl")
    otel_file           = file("${local.edge_dir}/otel/edge-collector.yaml")
    oxidized_file       = file("${local.edge_dir}/oxidized/config.ctmpl")
  })
}

output "first_ssh_key" {
  value = var.ssh_authorized_keys[0]
}
