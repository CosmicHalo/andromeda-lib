{
  core-inputs,
  user-inputs,
  snowfall-lib,
  snowfall-config,
  ...
}: let
  inherit (core-inputs.nixpkgs.lib) filterAttrs const;
in rec {
  flake = rec {
    without-src = flake-inputs: builtins.removeAttrs flake-inputs ["src"];
    without-self = flake-inputs: builtins.removeAttrs flake-inputs ["self"];
    without-snowfall-inputs = snowfall-lib.fp.compose without-self without-src;

    ## Remove Snowfall-specific attributes so the rest can be safely passed to flake-utils-plus.
    without-snowfall-options = flake-options:
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
        "snowfall"
      ];

    ## Transform an attribute set of inputs into an attribute set where the values are the inputs' `lib` attribute. Entries without a `lib` attribute are removed.
    get-libs = attrs: let
      # @PERF(jakehamilton): Replace filter+map with a fold.
      attrs-with-libs =
        filterAttrs
        (_name: value: builtins.isAttrs (value.lib or null))
        attrs;
      libs =
        builtins.mapAttrs (_name: input: input.lib) attrs-with-libs;
    in
      libs;
  };

  mkFlake = full-flake-options: let
    custom-flake-options = flake.without-snowfall-options full-flake-options;
    package-namespace = full-flake-options.package-namespace or snowfall-config.namespace or "internal";

    # Systems
    systems = snowfall-lib.system.create-systems {
      homes = full-flake-options.homes or {};
      systems = full-flake-options.systems or {};
      hosts = full-flake-options.systems.hosts or {};
    };

    # Overlays
    overlays = snowfall-lib.overlay.create-overlays {
      inherit package-namespace;
      extra-overlays = full-flake-options.extra-exported-overlays or {};
    };

    # Templates
    templates = snowfall-lib.template.create-templates {
      overrides = full-flake-options.templates or {};
      alias = alias.templates or {};
    };

    # Modules
    nixos-modules = snowfall-lib.module.create-modules {
      src = snowfall-lib.fs.get-snowfall-file "modules/nixos";
      overrides = full-flake-options.modules.nixos or {};
      alias = alias.modules.nixos or {};
    };
    darwin-modules = snowfall-lib.module.create-modules {
      src = snowfall-lib.fs.get-snowfall-file "modules/darwin";
      overrides = full-flake-options.modules.darwin or {};
      alias = alias.modules.darwin or {};
    };
    home-modules = snowfall-lib.module.create-modules {
      src = snowfall-lib.fs.get-snowfall-file "modules/home";
      overrides = full-flake-options.modules.home or {};
      alias = alias.modules.home or {};
    };

    alias = full-flake-options.alias or {};
    homes = snowfall-lib.home.create-homes (full-flake-options.homes or {});
    hosts = snowfall-lib.attrs.merge-shallow [systems homes];

    outputs-builder = channels: let
      user-outputs-builder =
        full-flake-options.outputs-builder
        or full-flake-options.outputsBuilder
        or (const {});

      user-outputs = user-outputs-builder channels;

      packages = snowfall-lib.package.create-packages {
        inherit channels package-namespace;
        overrides = (full-flake-options.packages or {}) // (user-outputs.packages or {});
        alias = alias.packages or {};
      };

      shells = snowfall-lib.shell.create-shells {
        inherit channels;
        overrides = (full-flake-options.shells or {}) // (user-outputs.devShells or {});
        alias = alias.shells or {};
      };

      outputs = {
        inherit packages;
        devShells = shells;
      };
    in
      snowfall-lib.attrs.merge-deep [user-outputs outputs];

    flake-options =
      custom-flake-options
      // {
        inherit hosts templates;
        inherit (user-inputs) self;

        lib = snowfall-lib.internal.user-lib;
        inputs = snowfall-lib.flake.without-src user-inputs;

        nixosModules = nixos-modules;
        darwinModules = darwin-modules;
        homeModules = home-modules;

        channelsConfig = full-flake-options.channels-config or {};

        channels.nixpkgs.overlaysBuilder = snowfall-lib.overlay.create-overlays-builder {
          inherit package-namespace;
          extra-overlays = full-flake-options.overlays or [];
        };

        outputsBuilder = outputs-builder;

        _snowfall = {
          config = snowfall-config;
          inherit (snowfall-lib.internal) user-lib;
          raw-config = full-flake-options.snowfall or {};
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
