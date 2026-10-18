# Renders this site's secrets into /etc/ops-edge/edge.env. The AppRole secret_id is delivered once,
# response-wrapped with a short TTL, by cloud-init; the agent unwraps it and removes the file.
# The server address comes from BAO_ADDR in /etc/ops-edge/site.env.

auto_auth {
  method "approle" {
    config = {
      role_id_file_path                   = "/etc/ops-edge/role_id"
      secret_id_file_path                 = "/etc/ops-edge/secret_id"
      secret_id_response_wrapping_path    = "auth/approle/role/edge/secret-id"
      remove_secret_id_file_after_reading = true
    }
  }
}

template {
  source      = "/etc/ops-edge/edge.env.tpl"
  destination = "/etc/ops-edge/edge.env"
  perms       = "0600"
}

template {
  source      = "/opt/ops-edge/oxidized/config.ctmpl"
  destination = "/opt/ops-edge/oxidized/config"
  perms       = "0640"
}
