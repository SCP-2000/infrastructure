{ config, lib, pkgs, ... }:
let
  mkService = { ExecStart, EnvironmentFile ? null, restartTriggers ? [ ] }: {
    inherit restartTriggers;
    serviceConfig = {
      MemoryLimit = "300M";
      DynamicUser = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      PrivateUsers = true;
      PrivateDevices = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectProc = "invisible";
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      CapabilityBoundingSet = "";
      ProtectHostname = true;
      ProcSubset = "pid";
      SystemCallArchitectures = "native";
      UMask = "0077";
      SystemCallFilter = "@system-service";
      SystemCallErrorNumber = "EPERM";
      Restart = "always";
      inherit ExecStart EnvironmentFile;
    };
    wantedBy = [ "multi-user.target" ];
  };
  vault-config = (pkgs.formats.json { }).generate "config.json" {
    listener = [{
      tcp = {
        address = "[::1]:8200";
        cluster_address = "[::1]:8201";
        tls_disable = true;
      };
    }];
    storage = {
      file.path = "/var/lib/vault"; # TODO: read from env
    };
    ui = true;
    api_addr = "https://vault.nichi.co";
    cluster_addr = "https://[::1]:8201";
  };
  vault-agent = (pkgs.formats.json { }).generate "agent.json" {
    vault = {
      address = "https://vault.nichi.co";
    };
    cache = {
      use_auto_auth_token = "force";
    };
    listener = [{
      tcp = {
        address = "[::1]:9200";
        tls_disable = true;
      };
    }];
    auto_auth = {
      method = [{
        type = "approle";
        config = {
          role_id_file_path = "/run/secrets/vault-agent-roleid";
          secret_id_file_path = "/run/secrets/vault-agent-secretid";
          remove_secret_id_file_after_reading = false;
        };
      }];
    };
    template = [
      {
        contents = ''{{ with secret "consul/root/issue/consul" "ttl=24h" "common_name=server.global.consul" }}{{ .Data.issuing_ca }}{{ end }}'';
        destination = "/tmp/consul_ca.crt";
        error_on_missing_key = true;
      }
      {
        contents = ''{{ with secret "consul/root/issue/consul" "ttl=24h" "common_name=server.global.consul" }}{{ .Data.certificate }}{{ end }}'';
        destination = "/tmp/consul_server.crt";
        error_on_missing_key = true;
      }
      {
        contents = ''{{ with secret "consul/root/issue/consul" "ttl=24h" "common_name=server.global.consul" }}{{ .Data.private_key }}{{ end }}'';
        destination = "/tmp/consul_server.key";
        error_on_missing_key = true;
      }
      {
        contents = ''{{ with secret "nomad/root/issue/nomad" "ttl=24h" "common_name=server.global.nomad" }}{{ .Data.issuing_ca }}{{ end }}'';
        destination = "/tmp/nomad_ca.crt";
        error_on_missing_key = true;
      }
      {
        contents = ''{{ with secret "nomad/root/issue/nomad" "ttl=24h" "common_name=server.global.nomad" }}{{ .Data.certificate }}{{ end }}'';
        destination = "/tmp/nomad_server.crt";
        error_on_missing_key = true;
      }
      {
        contents = ''{{ with secret "nomad/root/issue/nomad" "ttl=24h" "common_name=server.global.nomad" }}{{ .Data.private_key }}{{ end }}'';
        destination = "/tmp/nomad_server.key";
        error_on_missing_key = true;
      }
    ];
  };
  consul-config = (pkgs.formats.json { }).generate "consul.json" {
    acl = {
      enabled = false;
    };
    advertise_addr_ipv4 = "{{ GetPublicInterfaces | include \"type\" \"IPv4\" | limit 1 | attr \"address\" }}";
    advertise_addr_ipv6 = "{{ GetPublicInterfaces | include \"type\" \"IPv6\" | limit 1 | attr \"address\" }}";
    bind_addr = "{{ GetPublicInterfaces | include \"type\" \"IPv4\" | limit 1 | attr \"address\" }}";
    autopilot = {
      last_contact_threshold = "10s";
      server_stabilization_time = "30s";
    };
    auto_config = {
      authorization = {
        enabled = true;
        static = {
          oidc_discovery_url = "https://vault.nichi.co/v1/identity/oidc";
          bound_issuer = "https://vault.nichi.co/v1/identity/oidc";
          bound_audiences = [ "node" ];
          jwt_supported_algs = [ "ES512" ];
        };
      };
    };
    bootstrap_expect = 1;
    connect = {
      enabled = true;
      ca_provider = "vault";
      ca_config = {
        address = "http://[::1]:9200";
        token = "s.yVz3Wuju52MT50UlSHpe37yG"; # fake token
        root_pki_path = "connect/root";
        intermediate_pki_path = "connect/intermediate";
      };
    };
    datacenter = "global";
    # encrypt = "";
    disable_keyring_file = true;
    ports = {
      http = -1;
      https = 8501;
    };
    server = true;
    ui_config.enabled = true;
    ca_file = "/tmp/consul_ca.crt";
    cert_file = "/tmp/consul_server.crt";
    key_file = "/tmp/consul_server.key";
    verify_incoming = true;
    verify_outgoing = true;
    verify_server_hostname = true;
  };
  nomad-config = (pkgs.formats.json { }).generate "nomad.json" {
    acl = {
      enabled = false;
    };
    advertise = {
      serf = "{{ GetPublicInterfaces | include \"type\" \"IPv4\" | limit 1 | attr \"address\" }}";
      http = "{{ GetPublicInterfaces | include \"type\" \"IPv4\" | limit 1 | attr \"address\" }}";
      rpc = "{{ GetPublicInterfaces | include \"type\" \"IPv4\" | limit 1 | attr \"address\" }}";
    };
    consul = {
      address = "127.0.0.1:8501";
      ca_file = "/tmp/consul_ca.crt";
      cert_file = "/tmp/consul_server.crt";
      key_file = "/tmp/consul_server.key";
      ssl = true;
      verify_ssl = false; # TODO: true
    };
    server = {
      enabled = true;
      bootstrap_expect = 1;
      # encrypt =
    };
    tls = {
      ca_file = "/tmp/nomad_ca.crt";
      cert_file = "/tmp/nomad_server.crt";
      key_file = "/tmp/nomad_server.key";
      http = true;
      rpc = true;
      verify_https_client = true;
      verify_server_hostname = true;
    };
    vault = {
      enabled = false; # TODO: true
      address = "http://[::1]:9200";
      token = "s.yVz3Wuju52MT50UlSHpe37yG"; # fake token
    };
  };
in
{
  sops = {
    defaultSopsFile = ./secrets.yaml;
    sshKeyPaths = [ "/var/lib/sops.key" ];
    secrets = {
      minio = { };
      telegraf = { };
      nixbot = { };
      meow = { };
      vault-agent-roleid = { mode = "0444"; };
      vault-agent-secretid = { mode = "0444"; };
    };
  };

  systemd.services.vault-agent = {
    description = "HashiCorp Vault Agent - A tool for managing secrets";
    documentation = [ "https://www.vaultproject.io/docs/agent" ];
    requires = [ "network-online.target" ];
    after = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      DynamicUser = true;
      PrivateDevices = true;
      ExecStart = "${pkgs.vault-bin}/bin/vault agent -config=${vault-agent}";
      KillMode = "process";
      KillSignal = "SIGINT";
      Restart = "on-failure";
      RestartSec = 5;
      TimeoutStopSec = 30;
    };
    unitConfig = {
      StartLimitIntervalSec = 60;
      StartLimitBurst = 3;
    };
  };

  systemd.services.vault = {
    description = "HashiCorp Vault - A tool for managing secrets";
    documentation = [ "https://vaultproject.io/docs" ];
    requires = [ "network-online.target" ];
    after = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      DynamicUser = true;
      PrivateDevices = true;
      SecureBits = "keep-caps";
      AmbientCapabilities = "CAP_IPC_LOCK";
      CapabilityBoundingSet = "CAP_SYSLOG CAP_IPC_LOCK";
      LimitMEMLOCK = "infinity";
      StateDirectory = "vault";
      ExecStart = "${pkgs.vault-bin}/bin/vault server -config=${vault-config}";
      ExecReload = "${pkgs.util-linux}/bin/kill --signal HUP $MAINPID";
      KillMode = "process";
      KillSignal = "SIGINT";
      Restart = "on-failure";
      RestartSec = 5;
      TimeoutStopSec = 30;
    };
    unitConfig = {
      StartLimitIntervalSec = 60;
      StartLimitBurst = 3;
    };
  };

  systemd.services.nomad = {
    description = "HashiCorp Nomad - A simple and flexible workload orchestrator";
    documentation = [ "https://www.nomadproject.io/docs" ];
    requires = [ "network-online.target" "vault-agent.service" ];
    after = [ "network-online.target" "vault-agent.service" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig = {
      JoinsNamespaceOf = "vault-agent.service";
    };
    serviceConfig = {
      DynamicUser = true;
      StateDirectory = "nomad";
      ExecStart = "${pkgs.nomad}/bin/nomad agent -data-dir=\${STATE_DIRECTORY} -config=${nomad-config}";
      ExecReload = "${pkgs.util-linux}/bin/kill --signal HUP $MAINPID";
      KillMode = "process";
      KillSignal = "SIGINT";
      Restart = "on-failure";
      LimitNOFILE = "65536";
      LimitNPROC = "infinity";
      RestartSec = 2;
      TasksMax = "infinity";
      OOMScoreAdjust = -1000;
    };
  };

  systemd.services.consul = {
    description = "HashiCorp Consul - A service mesh solution";
    documentation = [ "https://www.consul.io/docs" ];
    requires = [ "network-online.target" "vault-agent.service" ];
    after = [ "network-online.target" "vault-agent.service" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig = {
      JoinsNamespaceOf = "vault-agent.service";
    };
    serviceConfig = {
      # Type = "notify";
      DynamicUser = true;
      StateDirectory = "consul";
      ExecStart = "${pkgs.consul}/bin/consul agent -data-dir=\${STATE_DIRECTORY} -config-file=${consul-config}";
      ExecReload = "${pkgs.util-linux}/bin/kill --signal HUP $MAINPID";
      KillMode = "process";
      KillSignal = "SIGTERM";
      Restart = "on-failure";
      LimitNOFILE = "65536";
    };
  };

  systemd.services.meow = mkService {
    ExecStart = "${pkgs.meow}/bin/meow";
    EnvironmentFile = config.sops.secrets.meow.path;
    restartTriggers = [ config.sops.secrets.meow.sopsFileHash ];
  };

  systemd.services.nixbot = {
    serviceConfig = {
      DynamicUser = true;
      WorkingDirectory = "/tmp";
      PrivateTmp = true;
      Restart = "always";
      LoadCredential = "nixbot:${config.sops.secrets.nixbot.path}";
    };
    script = ''
      exec ${pkgs.nixbot-telegram}/bin/nixbot-telegram ''${CREDENTIALS_DIRECTORY}/nixbot
    '';
    wantedBy = [ "multi-user.target" ];
  };

  security.wrappers.smartctl.source = "${pkgs.smartmontools}/bin/smartctl";
  services.telegraf = {
    enable = true;
    environmentFiles = [ config.sops.secrets.telegraf.path ];
    extraConfig = {
      outputs = {
        influxdb_v2 = {
          urls = [ "https://stats.nichi.co" ];
          token = "$INFLUX_TOKEN";
          organization = "nichi";
          bucket = "stats";
        };
      };
      inputs = {
        cpu = { };
        disk = { };
        diskio = { };
        mem = { };
        net = { };
        system = { };
        smart = {
          path_smartctl = "${config.security.wrapperDir}/smartctl";
          path_nvme = "${pkgs.nvme-cli}/bin/nvme";
          devices = [ "/dev/disk/by-id/wwn-0x50000397fc5003aa -d ata" "/dev/disk/by-id/wwn-0x500003981ba001ae -d ata" ];
        };
      };
    };
  };

  services.minio = {
    enable = true;
    browser = false;
    listenAddress = "127.0.0.1:9000";
    rootCredentialsFile = config.sops.secrets.minio.path;
  };

  services.influxdb2 = {
    enable = true;
    settings = {
      http-bind-address = "127.0.0.1:8086";
    };
  };

  services.traefik = {
    enable = true;
    staticConfigOptions = {
      experimental.http3 = true;
      entryPoints = {
        http = {
          address = ":80";
          http.redirections.entryPoint = {
            to = "https";
            scheme = "https";
            permanent = false;
          };
        };
        https = {
          address = ":443";
          http.tls.certResolver = "le";
          enableHTTP3 = true;
        };
      };
      certificatesResolvers.le.acme = {
        email = "blackhole@nichi.co";
        storage = config.services.traefik.dataDir + "/acme.json";
        keyType = "EC256";
        tlsChallenge = { };
      };
      ping = {
        manualRouting = true;
      };
    };
    dynamicConfigOptions = {
      tls.options.default = {
        minVersion = "VersionTLS12";
        sniStrict = true;
      };
      http = {
        routers = {
          ping = {
            rule = "Host(`hel0.nichi.link`)";
            service = "ping@internal";
          };
          minio = {
            rule = "Host(`s3.nichi.co`)";
            service = "minio";
          };
          meow = {
            rule = "Host(`pb.nichi.co`)";
            service = "meow";
          };
          influx = {
            rule = "Host(`stats.nichi.co`)";
            service = "influx";
          };
          vault = {
            rule = "Host(`vault.nichi.co`)";
            service = "vault";
          };
        };
        services = {
          minio.loadBalancer = {
            passHostHeader = true;
            servers = [{ url = "http://${config.services.minio.listenAddress}"; }];
          };
          meow.loadBalancer = {
            passHostHeader = true;
            servers = [{ url = "http://127.0.0.1:8002"; }];
          };
          influx.loadBalancer = {
            passHostHeader = true;
            servers = [{ url = "http://${config.services.influxdb2.settings.http-bind-address}"; }];
          };
          vault.loadBalancer = {
            passHostHeader = true;
            servers = [{ url = "http://[::1]:8200"; }];
          };
        };
      };
    };
  };
}
