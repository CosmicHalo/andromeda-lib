{
  core-inputs,
  user-inputs,
  snowfall-lib,
  ...
}: let
  inherit (core-inputs.flake-utils-plus.lib) filterPackages;
  inherit (core-inputs.nixpkgs.lib) foldl mapAttrs callPackageWith;

  user-packages-root = snowfall-lib.fs.get-snowfall-file "packages";
in {
  package = {
    ## Create flake output packages.
    create-packages = {
      channels,
      src ? user-packages-root,
      pkgs ? channels.nixpkgs,
      overrides ? {},
      alias ? {},
      package-namespace ? "internal",
    }: let
      user-packages = snowfall-lib.fs.get-default-nix-files-recursive src;
      create-package-metadata = package: let
        namespaced-packages = {
          ${package-namespace} = packages-without-aliases;
        };
        extra-inputs =
          pkgs
          // namespaced-packages
          // {
            inherit channels;
            lib = snowfall-lib.internal.system-lib;
            pkgs = pkgs // namespaced-packages;
            inputs = snowfall-lib.flake.without-snowfall-inputs user-inputs;
          };
      in {
        name = builtins.unsafeDiscardStringContext (snowfall-lib.path.get-parent-directory package);
        drv = let
          pkg = callPackageWith extra-inputs package {};
        in
          pkg
          // {
            meta =
              (pkg.meta or {})
              // {
                snowfall = {
                  path = package;
                };
              };
          };
      };
      packages-metadata = builtins.map create-package-metadata user-packages;
      merge-packages = packages: metadata:
        packages
        // {
          ${metadata.name} = metadata.drv;
        };
      packages-without-aliases = foldl merge-packages {} packages-metadata;
      aliased-packages = mapAttrs (name: value: packages-without-aliases.${value}) alias;
      packages = packages-without-aliases // aliased-packages // overrides;
    in
      filterPackages pkgs.system packages;
  };
}
