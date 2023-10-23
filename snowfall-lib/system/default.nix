{
  core-inputs,
  user-inputs,
  snowfall-lib,
  ...
}: let
  inherit (builtins) baseNameOf;
  inherit (core-inputs.nixpkgs.lib) assertMsg fix hasInfix concatMap foldl optionals foldlAttrs;

  virtual-systems = import ./virtual-systems.nix;

  user-systems-root = snowfall-lib.fs.get-snowfall-file "systems";
  user-modules-root = snowfall-lib.fs.get-snowfall-file "modules";
in {
  system = rec {
    is-linux = hasInfix "linux";
    is-darwin = hasInfix "darwin";
    is-virtual = target: (get-virtual-system-type target) != "";

    ## Get the name of a system based on its file path.
    get-inferred-system-name = path:
      if snowfall-lib.path.has-file-extension "nix" path
      then snowfall-lib.path.get-parent-directory path
      else baseNameOf path;

    ## Get the virtual system type of a system target.
    get-virtual-system-type = target:
      foldl
      (
        result: virtual-system:
          if result == "" && hasInfix virtual-system target
          then virtual-system
          else result
      )
      ""
      virtual-systems;

    ## Get structured data about all systems for a given target.
    get-target-systems-metadata = target: let
      systems = snowfall-lib.fs.get-directories target;
      existing-systems = builtins.filter (system: builtins.pathExists "${system}/default.nix") systems;
      create-system-metadata = path: {
        path = "${path}/default.nix";
        # We are building flake outputs based on file contents. Nix doesn't like this
        # so we have to explicitly discard the string's path context to allow us to
        # use the name as a variable.
        name = builtins.unsafeDiscardStringContext (builtins.baseNameOf path);
        # We are building flake outputs based on file contents. Nix doesn't like this
        # so we have to explicitly discard the string's path context to allow us to
        # use the name as a variable.
        target = builtins.unsafeDiscardStringContext (builtins.baseNameOf target);
      };
      system-configurations = builtins.map create-system-metadata existing-systems;
    in
      system-configurations;

    ## Get the flake output attribute for a system target.
    get-system-output = target: let
      virtual-system-type = get-virtual-system-type target;
    in
      if virtual-system-type != ""
      then "${virtual-system-type}Configurations"
      else if is-darwin target
      then "darwinConfigurations"
      else "nixosConfigurations";

    ## Get the system builder for a given target.
    get-system-builder = target: let
      virtual-system-type = get-virtual-system-type target;
      virtual-system-builder = args:
        assert assertMsg (user-inputs ? nixos-generators) "In order to create virtual systems, you must include `nixos-generators` as a flake input.";
          user-inputs.nixos-generators.nixosGenerate
          (args
            // {
              format = virtual-system-type;
              specialArgs =
                args.specialArgs
                // {
                  format = virtual-system-type;
                };
              modules =
                args.modules
                ++ [
                  core-inputs.self.nixosModules
                ];
            });
      darwin-system-builder = args:
        assert assertMsg (user-inputs ? darwin) "In order to create virtual systems, you must include `darwin` as a flake input.";
          user-inputs.darwin.lib.darwinSystem
          ((builtins.removeAttrs args ["system" "modules"])
            // {
              specialArgs =
                args.specialArgs
                // {
                  format = "darwin";
                };
              modules =
                args.modules
                ++ [
                  core-inputs.self.darwinModules
                ];
            });
      linux-system-builder = args:
        core-inputs.nixpkgs.lib.nixosSystem
        (args
          // {
            specialArgs =
              args.specialArgs
              // {
                format = "linux";
              };
            modules =
              args.modules
              ++ [
                core-inputs.self.nixosModules
              ];
          });
    in
      if virtual-system-type != ""
      then virtual-system-builder
      else if is-darwin target
      then darwin-system-builder
      else linux-system-builder;

    ## Get the resolved (non-virtual) system target.
    get-resolved-system-target = target: let
      virtual-system-type = get-virtual-system-type target;
    in
      if virtual-system-type != ""
      then builtins.replaceStrings [virtual-system-type] ["linux"] target
      else target;

    ## Create a system.
    create-system = {
      target ? "x86_64-linux",
      system ? get-resolved-system-target target,
      path,
      name ? builtins.unsafeDiscardStringContext (get-inferred-system-name path),
      modules ? [],
      specialArgs ? {},
      channelName ? "nixpkgs",
      builder ? get-system-builder target,
      output ? get-system-output target,
      systems ? {},
      homes ? {},
    }: let
      lib = snowfall-lib.internal.system-lib;
      home-system-modules = snowfall-lib.home.create-home-system-modules homes;
      home-manager-module =
        if is-darwin system
        then user-inputs.home-manager.darwinModules.home-manager
        else user-inputs.home-manager.nixosModules.home-manager;
      home-manager-modules = [home-manager-module] ++ home-system-modules;
    in {
      inherit channelName system builder output;

      modules = [path] ++ modules ++ (optionals (user-inputs ? home-manager) home-manager-modules);

      specialArgs =
        specialArgs
        // {
          inherit target system systems lib;
          host = name;

          virtual = (get-virtual-system-type target) != "";
          inputs = snowfall-lib.flake.without-src user-inputs;
        };
    };

    ## Create all available systems.
    create-systems = {
      hosts ? {},
      homes ? {},
      systems ? {},
    }: let
      targets = snowfall-lib.fs.get-directories user-systems-root;
      target-systems-metadata = concatMap get-target-systems-metadata targets;
      user-nixos-modules = snowfall-lib.module.create-modules {
        src = "${user-modules-root}/nixos";
      };
      user-darwin-modules = snowfall-lib.module.create-modules {
        src = "${user-modules-root}/darwin";
      };
      nixos-modules = systems.modules.nixos or [];
      darwin-modules = systems.modules.darwin or [];

      # Get all modules for a given target.
      get-modules = target: overrides: let
        user-modules =
          if is-darwin target
          then user-darwin-modules
          else user-nixos-modules;
        system-modules =
          if is-darwin target
          then darwin-modules
          else nixos-modules;
      in
        (builtins.attrValues user-modules) ++ overrides ++ system-modules;

      create-system' = created-systems: system-metadata: let
        overrides = systems.hosts.${system-metadata.name} or {};
        modules = get-modules system-metadata.target (overrides.modules or []);
      in {
        ${system-metadata.name} = create-system (overrides
          // system-metadata
          // {
            inherit homes modules;
            systems = created-systems;
          });
      };

      # Merge all host defined systems with modules of flake.
      host-systems =
        foldlAttrs
        (
          acc: name: v:
            acc
            // {
              ${name} = let
                target = v.output or "nixosConfigurations";
                modules = get-modules target (v.modules or []);
              in
                create-system (v
                  // {
                    inherit homes modules;
                    systems = created-systems;
                  });
            }
        ) {}
        hosts;

      created-systems = fix (
        created-systems:
          foldl
          (
            systems: system-metadata:
              systems // (create-system' created-systems system-metadata)
          )
          {}
          target-systems-metadata
      );
    in
      snowfall-lib.attrs.merge-shallow [host-systems created-systems];
  };
}
