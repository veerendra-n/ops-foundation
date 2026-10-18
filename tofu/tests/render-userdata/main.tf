# CI check: renders the edge node user data with fictitious values so template errors fail the build.
# tools/test_userdata.sh writes the output to build/ and checks it parses as cloud-config.
module "userdata" {
  source              = "../../modules/edge-node-userdata"
  tenant_id           = "lab"
  site_id             = "hq"
  bao_addr            = "https://bao.lab.example:8200"
  oo_endpoint         = "https://observe.lab.example"
  ssh_authorized_keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKeyOnly lab"]
  role_id             = "00000000-0000-0000-0000-000000000000"
  wrapped_secret_id   = "example-wrapped-token"
}

output "user_data" {
  value     = module.userdata.user_data
  sensitive = true
}
