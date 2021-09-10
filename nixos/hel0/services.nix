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
      use_auto_auth_token = true;
    };
    listener = [{
      unix = {
        address = "/tmp/agent.sock";
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
    documentation = [ "https://www.vaultproject.io/docs/agent/" ];
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
      StartLimitIntervalSec = 60;
      StartLimitBurst = 3;
    };
  }; 
    
  systemd.services.vault = {
    description = "HashiCorp Vault - A tool for managing secrets";
    documentation = [ "https://vaultproject.io/docs/" ];
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
      StartLimitIntervalSec = 60;
      StartLimitBurst = 3;
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
