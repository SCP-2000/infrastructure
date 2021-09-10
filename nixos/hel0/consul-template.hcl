vault {
  address = "https://vault.nichi.co"
  ssl {
    verify = true
  }
}

// {{ with secret "gossip/data/consul" }}consul gossip: {{ .Data.data.key }}{{ end }}
// {{ with secret "gossip/data/nomad" }}nomad gossip: {{ .Data.data.key }}{{ end }}

template {
  contents = "{{ with secret \"nomad/root/issue/nomad\" \"ttl=24h\" \"common_name=dummy.nomad\" }}{{ .Data.issuing_ca }}{{ end }}"
  destination = "tmp/nomad-ca.crt"
  error_on_missing_key = true
}

template {
  contents = "{{ with secret \"nomad/root/issue/nomad\" \"ttl=24h\" \"common_name=server.global.nomad\" \"alt_names=localhost\" \"ip_sans=127.0.0.1\" }}{{ .Data.certificate }}{{ end }}"
  destination = "tmp/nomad-server.crt"
  error_on_missing_key = true
}

template {
  contents = "{{ with secret \"nomad/root/issue/nomad\" \"ttl=24h\" \"common_name=server.global.nomad\" \"alt_names=localhost\" \"ip_sans=127.0.0.1\" }}{{ .Data.private_key }}{{ end }}"
  destination = "tmp/nomad-server.key"
  error_on_missing_key = true
}

template {
  contents = "{{ with secret \"consul/root/issue/consul\" \"ttl=24h\" \"common_name=dummy.consul\" }}{{ .Data.issuing_ca }}{{ end }}"
  destination = "tmp/consul-ca.crt"
  error_on_missing_key = true
}

template {
  contents = "{{ with secret \"consul/root/issue/consul\" \"ttl=24h\" \"common_name=server.global.consul\" \"alt_names=localhost\" \"ip_sans=127.0.0.1\" }}{{ .Data.certificate }}{{ end }}"
  destination = "tmp/consul-server.crt"
  error_on_missing_key = true
}

template {
  contents = "{{ with secret \"consul/root/issue/consul\" \"ttl=24h\" \"common_name=server.global.consul\" \"alt_names=localhost\" \"ip_sans=127.0.0.1\" }}{{ .Data.private_key }}{{ end }}"
  destination = "tmp/consul-server.key"
  error_on_missing_key = true
}