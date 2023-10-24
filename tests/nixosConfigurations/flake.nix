{
  inputs = {
    utils.url = "path:../../";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs @ {
    self,
    utils,
    nixpkgs,
    ...
  }: let
    base-nixos = {
      boot.loader.grub.devices = ["nodev"];
      fileSystems."/" = {
        device = "test";
        fsType = "ext4";
      };
    };

    test-lib = {
      inherit self inputs;
      src = ./.;

      andromeda = {
        namespace = "test";
        meta = {
          name = "test";
          title = "Test Lib";
        };
      };
    };
  in
    utils.lib.mkFlake (test-lib
      // {
        channels.nixpkgs.input = nixpkgs;
        channels.someChannel.input = nixpkgs;

        systems.hosts = {
          "com.example.myhost".modules = [base-nixos];

          Customized = {
            system = "x86_64-linux";
            channelName = "someChannel";
            output = "nixosConfigurations";

            extraArgs.hostExtraArg = "hostExtraArg";
            specialArgs.hostSpecialArg = "hostSpecialArg";

            modules = [
              base-nixos

              ({
                hostExtraArg,
                hostSpecialArg,
                ...
              }: {
                lib = {inherit hostSpecialArg hostExtraArg;};
              })
            ];
          };
        };

        ######################
        ### Test execution ###
        ######################

        outputsBuilder = channels: {
          checks = let
            inherit (utils.lib.check-utils channels.nixpkgs) hasKey isEqual;

            # Plain system
            testHost = self.nixosConfigurations.testhost;
            testHostPkgs = testHost.config.nixpkgs.pkgs;
            testHostName = testHost.config.networking.hostName;
            testHostDomain = testHost.config.networking.domain;

            # Reverse
            reverseDnsHost = self.nixosConfigurations."com.example.myhost";
            reverseDnsHostName = reverseDnsHost.config.networking.hostName;
            reverseDnsHostDomain = reverseDnsHost.config.networking.domain;

            # Customized host
            customizedHost = self.nixosConfigurations.Customized;
            customizedHostPkgs = customizedHost.config.nixpkgs.pkgs;
          in {
            # Plain system with inherited options from hostDefaults
            system_valid_1 = isEqual testHostPkgs.system "x86_64-linux";
            channelName_valid_1 = isEqual testHostPkgs.name "nixpkgs";
            channelInput_valid_1 = hasKey testHostPkgs "input";
            hostName_valid_1 = isEqual testHostName "testhost";
            domain_valid_1 = isEqual testHostDomain null;

            # System with overwritten hostDefaults
            system_valid_2 = isEqual customizedHostPkgs.system "x86_64-linux";
            channelName_valid_2 = isEqual customizedHostPkgs.name "someChannel";
            channelInput_valid_2 = hasKey customizedHostPkgs "input";
            extraArgs_valid_2 = hasKey customizedHost.config.lib "hostExtraArg";
            specialArgs_valid_2 = hasKey customizedHost.config.lib "hostSpecialArg";

            # Hostname and Domain set from reverse DNS name
            hostName_valid_3 = isEqual reverseDnsHostName "myhost";
            domain_valid_3 = isEqual reverseDnsHostDomain "example.com";
          };
        };
      });
}
