{
  sto-tazserve-1 = { pkgs, config, ... }: {
    deployment.targetHost = "46.21.106.241";

    # Configure root disk
    fileSystems."/" = {
      device = "/dev/disk/by-uuid/edb2a58c-561b-4597-9d88-9886cdfb1eac";
      fsType = "ext4";
    };

    # Configure network
    networking.hostName = "sto-tazserve-1";
    networking.interfaces.ens32.ip4 = [
      { address = "46.21.106.241"; prefixLength = 23; }
    ];
    networking.defaultGateway = "46.21.106.1";
    networking.nameservers = [ "195.20.206.80" "195.20.206.81" ];

    imports = [
      ./configuration.nix
      ./tazserve.nix
    ];
  };
}
