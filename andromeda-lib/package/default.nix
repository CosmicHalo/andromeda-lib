{
  core-inputs,
  user-inputs,
  andromeda-lib,
  ...
}: let
  inherit (core-inputs.flake-utils-plus.lib) filterPackages;
  inherit (core-inputs.nixpkgs.lib) foldl mapAttrs callPackageWith;

  user-packages-root = andromeda-lib.fs.get-andromeda-file "packages";
in {
  package = {
    ## Create flake output packages.
    create-packages = {
      channels,
      alias ? {},
      overrides ? {},
      pkgs ? channels.nixpkgs,
      src ? user-packages-root,
      package-namespace ? "internal",
    }: let
      user-packages = andromeda-lib.fs.get-default-nix-files-recursive src;
      create-package-metadata = package: let
        namespaced-packages = {
          ${package-namespace} = packages-without-aliases;
        };
        extra-inputs =
          pkgs
          // namespaced-packages
          // {
            inherit channels;
            lib = andromeda-lib.internal.system-lib;
            pkgs = pkgs // namespaced-packages;
            inputs = andromeda-lib.flake.without-andromeda-inputs user-inputs;
          };
      in {
        name = builtins.unsafeDiscardStringContext (andromeda-lib.path.get-parent-directory package);
        drv = let
          pkg = callPackageWith extra-inputs package {};
        in
          pkg
          // {
            meta =
              (pkg.meta or {})
              // {
                andromeda = {
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
      aliased-packages = mapAttrs (_name: value: packages-without-aliases.${value}) alias;
      packages = packages-without-aliases // aliased-packages // overrides;
    in
      filterPackages pkgs.system packages;
  };
}
