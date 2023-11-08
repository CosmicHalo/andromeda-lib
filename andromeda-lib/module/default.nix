{
  core-inputs,
  user-inputs,
  andromeda-lib,
  ...
}: let
  inherit (core-inputs.nixpkgs.lib) foldl mapAttrs hasPrefix;

  user-modules-root = andromeda-lib.fs.get-andromeda-file "modules";
in {
  module =
    import ./options.nix {inherit (core-inputs.nixpkgs) lib;}
    // {
      ## Create flake output modules.
      create-modules = {
        alias ? {},
        overrides ? {},
        channelName ? "nixpkgs",
        src ? "${user-modules-root}/nixos",
      }: let
        user-modules = andromeda-lib.fs.get-default-nix-files-recursive src;
        create-module-metadata = module: {
          name = let
            path-name = builtins.replaceStrings [src "/default.nix"] ["" ""] (builtins.unsafeDiscardStringContext module);
          in
            if hasPrefix "/" path-name
            then builtins.substring 1 ((builtins.stringLength path-name) - 1) path-name
            else path-name;
          path = module;
        };

        modules-metadata = builtins.map create-module-metadata user-modules;
        merge-modules = modules: metadata:
          modules
          // {
            # @NOTE(jakehamilton): home-manager *requires* modules to specify named arguments or it will not
            # pass values in. For this reason we must specify things like `pkgs` as a named attribute.
            ${metadata.name} = args @ {pkgs, ...}: let
              target = args.target or system;
              system = args.system or args.pkgs.system;
              channels = user-inputs.self.pkgs.${system};

              isLinux = andromeda-lib.system.is-linux target;
              isDarwin = andromeda-lib.system.is-darwin target;

              format = let
                virtual-system-type = andromeda-lib.system.get-virtual-system-type target;
              in
                if virtual-system-type != ""
                then virtual-system-type
                else if andromeda-lib.system.is-darwin target
                then "darwin"
                else "linux";

              # Replicates the specialArgs from Andromeda Lib's system builder.
              modified-args =
                args
                // {
                  inherit isDarwin isLinux;
                  inherit system target format channels;

                  pkgs = channels.${channelName};
                  lib = andromeda-lib.internal.system-lib;
                  inputs = andromeda-lib.flake.without-src user-inputs;

                  systems = args.systems or {};
                  virtual = args.virtual or (andromeda-lib.system.get-virtual-system-type target != "");
                };
              user-module = import metadata.path modified-args;
            in
              user-module // {_file = metadata.path;};
          };

        modules-without-aliases = foldl merge-modules {} modules-metadata;
        aliased-modules = mapAttrs (_name: value: modules-without-aliases.${value}) alias;
        modules = modules-without-aliases // aliased-modules // overrides;
      in
        modules;
    };
}
