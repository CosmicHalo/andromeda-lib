{
  core-inputs,
  user-inputs,
  andromeda-lib,
  andromeda-config,
  ...
}: let
  inherit (core-inputs.nixpkgs.lib) foldlAttrs const;
in rec {
  flake = rec {
    without-src = flake-inputs: builtins.removeAttrs flake-inputs ["src"];
    without-self = flake-inputs: builtins.removeAttrs flake-inputs ["self"];
    without-andromeda-inputs = andromeda-lib.fp.compose without-self without-src;

    ## Remove Andromeda-specific attributes so the rest can be safely passed to flake-utils-plus.
    without-andromeda-options = flake-options:
      builtins.removeAttrs
      flake-options
      [
        "systems"
        "modules"
        "overlays"
        "packages"
        "outputs-builder"
        "outputsBuilder"
        "packagesPrefix"
        "hosts"
        "channels-config"
        "templates"
        "package-namespace"
        "alias"
        "andromeda"
      ];

    ## Transform an attribute set of inputs into an attribute set where the values are the inputs' `lib` attribute. Entries without a `lib` attribute are removed.
    get-libs = attrs: let
      libs =
        foldlAttrs (acc: name: v:
          acc
          // (
            if builtins.isAttrs (v.lib or null)
            then {${name} = v.lib;}
            else {}
          ))
        {}
        attrs;
    in
      libs;
  };

  mkFlake = full-flake-options: let
    custom-flake-options = flake.without-andromeda-options full-flake-options;
    package-namespace = full-flake-options.package-namespace or andromeda-config.namespace or "internal";

    ##############
    # Systems
    ##############
    systems = andromeda-lib.system.create-systems {
      homes = full-flake-options.homes or {};
      systems = full-flake-options.systems or {};
      hosts = full-flake-options.systems.hosts or {};
    };

    ##############
    # Overlays
    ##############
    overlays = andromeda-lib.overlay.create-overlays {
      inherit package-namespace;
      extra-overlays = full-flake-options.extra-exported-overlays or {};
    };

    ##############
    # Templates
    ##############
    templates = andromeda-lib.template.create-templates {
      overrides = full-flake-options.templates or {};
      alias = alias.templates or {};
    };

    ##############
    # Modules
    ##############
    nixos-modules = andromeda-lib.module.create-modules {
      src = andromeda-lib.fs.get-andromeda-file "modules/nixos";
      overrides = full-flake-options.modules.nixos or {};
      alias = alias.modules.nixos or {};
    };
    darwin-modules = andromeda-lib.module.create-modules {
      src = andromeda-lib.fs.get-andromeda-file "modules/darwin";
      overrides = full-flake-options.modules.darwin or {};
      alias = alias.modules.darwin or {};
    };
    home-modules = andromeda-lib.module.create-modules {
      src = andromeda-lib.fs.get-andromeda-file "modules/home";
      overrides = full-flake-options.modules.home or {};
      alias = alias.modules.home or {};
    };

    alias = full-flake-options.alias or {};
    homes = andromeda-lib.home.create-homes (full-flake-options.homes or {});
    hosts = andromeda-lib.attrs.merge-shallow [systems homes];

    ##############
    # Channels
    ##############
    channels =
      {
        nixpkgs.overlaysBuilder = andromeda-lib.overlay.create-overlays-builder {
          inherit package-namespace;
          extra-overlays = full-flake-options.overlays or [];
        };
      }
      // full-flake-options.channels or {};
    channelsConfig = full-flake-options.channels-config or {};

    ##############
    # Output Builders
    ##############
    outputs-builder = channels: let
      user-outputs-builder =
        full-flake-options.outputs-builder
        or full-flake-options.outputsBuilder
        or (const {});

      user-outputs = user-outputs-builder channels;

      packages = andromeda-lib.package.create-packages {
        inherit channels package-namespace;
        overrides = (full-flake-options.packages or {}) // (user-outputs.packages or {});
        alias = alias.packages or {};
      };

      shells = andromeda-lib.shell.create-shells {
        inherit channels;
        overrides = (full-flake-options.shells or {}) // (user-outputs.devShells or {});
        alias = alias.shells or {};
      };

      outputs = {
        inherit packages;
        devShells = shells;
      };
    in
      andromeda-lib.attrs.merge-deep [user-outputs outputs];

    flake-options =
      custom-flake-options
      // {
        inherit hosts templates channels channelsConfig;
        inherit (user-inputs) self;

        lib = andromeda-lib.internal.user-lib;
        inputs = andromeda-lib.flake.without-src user-inputs;

        nixosModules = nixos-modules;
        darwinModules = darwin-modules;
        homeModules = home-modules;

        # channels.nixpkgs.overlaysBuilder = andromeda-lib.overlay.create-overlays-builder {
        #   inherit package-namespace;
        #   extra-overlays = full-flake-options.overlays or [];
        # };

        outputsBuilder = outputs-builder;

        _andromeda = {
          config = andromeda-config;
          inherit (andromeda-lib.internal) user-lib;
          raw-config = full-flake-options.andromeda or {};
        };
      };

    flake-utils-plus-outputs =
      core-inputs.flake-utils-plus.lib.mkFlake flake-options;

    flake-outputs =
      flake-utils-plus-outputs
      // {
        inherit overlays;
      };
  in
    flake-outputs;
}
